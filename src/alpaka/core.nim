import 
    httpcore,
    uri,
    tables,
    sequtils,
    asynchttpserver,
    asyncdispatch


# Router Types
type
    IRouteRequest* = tuple[
        reqMethod: HttpMethod,
        headers: HttpHeaders,
        url: Uri,
        body: string
    ]
    RouteResponse*  = ref object
        code*:      HttpCode
        headers*:   HttpHeaders
        body*:      string
    RouteContext*   = ref object
        request*:   IRouteRequest
        response*:  RouteResponse
        urlParams*: Table[string, string] 
    RouteResult*    = enum 
        none, find 
    RouteFunc*      = proc (ctx:RouteContext): RouteResult
    RouteHandler*   = proc (f:RouteFunc): RouteFunc
    Router*         = ref object
        handler:            RouteHandler
        notFoundHandler:    RouteHandler


# create router
proc newRouter*(handler: RouteHandler, notFoundHandler: RouteHandler): Router =
    result = Router(
        handler: handler,
        notFoundHandler: notFoundHandler
    )

# end of handler
proc final(ctx: RouteContext): RouteResult =
    return RouteResult.find


# routing for request
# asynchttpServer
proc routing*(router: Router, req: Request): Future[void] =
    let ctx = RouteContext(
        request:    ( 
            reqMethod:  req.reqMethod,
            headers:    req.headers,
            url:        req.url,
            body:       req.body
        ),
        response:   RouteResponse(
            code:       Http500,
            headers:    newHttpHeaders(),
            body:       ""
        ),
        urlParams:  initTable[string,string]()
    )
    var res = (router.handler final) ctx
    if res == RouteResult.none:
        res = (router.notFoundHandler final) ctx
    
    if res == RouteResult.none:
        return req.respond(Http500, "Internal Server Error")

    if ctx.response.body == nil:
        ctx.response.body = ""
        
    return req.respond(
        ctx.response.code
        , ctx.response.body
        , ctx.response.headers
    )
    

# varargs to seq
proc `@`[T](xs:openArray[T]): seq[T] = 
    var s: seq[T] = @[]
    for x in xs:
        s.add x
    return s

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
proc backup[T,U](table: Table[T,U]): seq[tuple[a: T, b: U]] =
    result = @[]
    for key in table.keys:
        result.add((key, table[key]))
# 
let abort* = RouteResult.none

# choose func until not abort
proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    return proc(ctx: RouteContext): RouteResult =
        let tempResponse = ctx.response.backup()
        let tempUrlParams = ctx.urlParams.backup()
        if funcs.len == 0:
            return abort
        else:
            let res = funcs[0] ctx
            if res != abort:
                return res
            else:
                # reset response
                ctx.response = tempResponse
                ctx.urlParams = tempUrlParams.toTable()
                # find other
                let f = chooseFuncs funcs[1..funcs.len-1]
                return f ctx

# choose handler until not abort
proc choose*(handlers: varargs[RouteHandler]): RouteHandler =
    var hx = @handlers
    return proc(final: RouteFunc): RouteFunc =
        var funcs = hx.map(proc(h:RouteHandler):RouteFunc = h final)
        return proc(ctx: RouteContext): RouteResult =
            return chooseFuncs(funcs) ctx


### context utils
proc resp*(ctx: RouteContext, code: HttpCode, content: string): RouteResult =
    ctx.response.code = code
    ctx.response.body = content
    return RouteResult.find

proc code*(ctx: RouteContext, code: HttpCode): RouteResult =
    ctx.response.code = code
    return RouteResult.find
    
proc text*(ctx: RouteContext, content: string): RouteResult =
    return ctx.resp(Http200, content)

proc setHeader*(ctx: RouteContext, key, val: string): void =
    ctx.response.headers.add(key, val)

proc getHeader*(ctx: RouteContext, key: string): string =
    return ctx.request.headers.getOrDefault(key)

proc redirect*(ctx: RouteContext, path: string, code: HttpCode = Http302 ): RouteResult =
    ctx.setHeader("Location", path)
    return ctx.code code
