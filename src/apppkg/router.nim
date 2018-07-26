import 
    asynchttpserver, 
    asyncdispatch,
    sequtils,
    tables,
    httpcore

# Router Types
type
    RouteResponse*  = ref object
        code*:      HttpCode
        headers*:   HttpHeaders
        body*:      string
    RouteContext*   = ref object
        request*:   Request
        response*:  RouteResponse   
    RouteResult*    = ref object
        context*:   RouteContext
    RouteFunc*      = proc (ctx:RouteContext): RouteResult
    RouteHandler*   = proc (f:RouteFunc): RouteFunc
    Router*         = ref object
        handler:            RouteHandler
        notFoundHandler:    RouteHandler

# backup responce
proc backup(res: RouteResponse): RouteResponse =
    let code = res.code
    let body = res.body
    let headers = newHttpHeaders()

    for key in res.headers.table.keys:
        for val in res.headers.table[key]:
            headers.add(key, val)
    return RouteResponse(
        code: code,
        body: body,
        headers: headers
    )




# send response from result
proc bindContext(ctx: RouteContext): Future[void] =
    return ctx.request.respond(
        ctx.response.code
        , ctx.response.body
        , ctx.response.headers
    )

# end of handler
proc final(ctx: RouteContext): RouteResult =
    return RouteResult(context:ctx)

# routing for request
proc routing*(router: Router, req: Request): Future[void] =
    let ctx = RouteContext(
        request:    req,
        response:   RouteResponse(
            code: Http500,
            headers: newHttpHeaders(),
            body: ""
        )
    )
    var res = (router.handler final) ctx
    if res == nil:
        res = (router.notFoundHandler final) ctx
    
    if res != nil:
        return res.context.bindContext()
    
    return req.respond(Http500, "Internal Server Error")


# create router
proc newRouter*(handler: RouteHandler, notFoundHandler: RouteHandler): Router =
    result = Router(
        handler: handler,
        notFoundHandler: notFoundHandler
    )
# 
let abort*:RouteResult = nil

# next bind
proc `>=>`*(h1,h2: RouteHandler): RouteHandler =
    return proc(f: RouteFunc): RouteFunc =
        let f2 = h2 f
        let f1 = h1 f2
        return proc(ctx: RouteContext): RouteResult = 
            return f1 ctx

# choose func is not abort
proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    return proc(ctx: RouteContext): RouteResult =
        let temp = ctx.response.backup()
        if funcs.len == 0:
            return nil
        else:
            let res = funcs[0] ctx
            if res != nil:
                return res
            else:
                ctx.response = temp
                let f = chooseFuncs funcs[1..funcs.len-1]
                return f ctx

# choose handler is not abort
proc choose*(handlers:seq[RouteHandler]): RouteHandler =
    return proc(f: RouteFunc): RouteFunc =
        let hx = handlers
        let funcs = hx.map(proc(h:RouteHandler):RouteFunc = h f)
        return proc(ctx: RouteContext): RouteResult =
            return chooseFuncs(funcs) ctx

# filter by context
proc filter*(isMatch:proc(ctx:RouteContext): bool): RouteHandler =
    return proc(f: RouteFunc): RouteFunc = 
        return proc(ctx:RouteContext): RouteResult =
            if isMatch ctx:
                return f ctx
            else:
                return abort

# filters
let get*    = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpGet)
let post*   = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpPost)

proc route*(path: string): RouteHandler =
    return filter(proc(ctx: RouteContext): bool = ctx.request.url.path == path )



# context utils
proc resp*(ctx: RouteContext, code: HttpCode, content: string): RouteResult =
    ctx.response.code = code
    ctx.response.body = content
    return RouteResult(context: ctx)

proc text*(ctx: RouteContext, content: string): RouteResult =
    return ctx.resp(Http200, content)