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
        reqMethod   : HttpMethod,
        headers     : HttpHeaders,
        url         : Uri,
        body        : string
    ]
    RouteResponse*  = ref object
        code*       : HttpCode
        headers*    : HttpHeaders
        body*       : string
    RouteContext*   = ref object
        request*    : IRouteRequest
        response*   : RouteResponse
        urlParams*  : Table[string, string] 
    RouteResult*    = enum 
        none, find 
    RouteFunc*      = proc (ctx:RouteContext): RouteResult
    RouteHandler*   = proc (f:RouteFunc): RouteFunc
    Router*         = ref object
        handler*    : RouteHandler

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
        return req.respond(Http500, "Internal Server Error")

    if ctx.response.body == nil:
        ctx.response.body = ""
        
    return req.respond(
        ctx.response.code
        , ctx.response.body
        , ctx.response.headers
    )
    


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
