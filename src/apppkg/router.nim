import 
    asynchttpserver, 
    asyncdispatch,
    sequtils,
    tables

# Router Types
type
    RouteResponse*  = ref object of RootObj
        code*:      HttpCode
        headers*:   HttpHeaders
        body*:      string
    RouteContext*   = ref object of RootObj
        request*:   Request
        response*:  RouteResponse   
    RouteResult*    = ref object of RootObj
        context*:   RouteContext
    RouteFunc*      = proc (ctx:RouteContext): RouteResult
    RouteHandler*   = proc (f:RouteFunc): RouteFunc
    Router*         = ref object of RootObj
        handler:            RouteHandler
        notFoundHandler:    RouteHandler

proc bindContext(ctx: RouteContext): Future[void] =
    return ctx.request.respond(
        ctx.response.code
        , ctx.response.body
        , ctx.response.headers
    )

proc final(ctx: RouteContext): RouteResult =
    return RouteResult(context:ctx)

proc routing*(router: Router, req: Request): Future[void] =
    let ctx = RouteContext(
        request:    req,
        response:   RouteResponse()
    )
    var res = (router.handler final) ctx
    if res == nil:
        res = (router.notFoundHandler final) ctx
    
    if res != nil:
        return res.context.bindContext()
    
    return req.respond(Http500, "Internal Server Error")


# router
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
        if funcs.len == 0:
            return nil
        else:
            let res = funcs[0] ctx
            if res != nil:
                return res
            else:
                let f = chooseFuncs funcs[1..funcs.len-1]
                return f ctx

# choose handler is not abort
proc choose*(handlers:seq[RouteHandler]): RouteHandler =
    return proc(f: RouteFunc): RouteFunc =
        let funcs = handlers.map(proc(h:RouteHandler):RouteFunc = h f)
        return proc(ctx: RouteContext): RouteResult =
            return chooseFuncs(funcs) ctx

# 
proc isMatchMethod(isMatch:proc(httpMethod:HttpMethod): bool): RouteHandler =
    return proc(f: RouteFunc): RouteFunc = 
        return proc(ctx:RouteContext): RouteResult =
            if isMatch ctx.request.reqMethod:
                return f ctx
            else:
                return abort

let get*    = isMatchMethod(proc(m:HttpMethod):bool = m == HttpGet)
let post*   = isMatchMethod(proc(m:HttpMethod):bool = m == HttpPost)

proc route*(path: string): RouteHandler =
    return proc(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            if ctx.request.url.path == path:
                return f ctx
            else:
                return abort
    