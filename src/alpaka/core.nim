import 
    httpcore,
    uri,
    tables,
    sequtils,
    strutils,
    asynchttpserver,
    asyncdispatch
import
    request,
    response,
    params
export
    request,
    response,
    params

type
    RouteResult*    = enum 
        none, find 
    RouteFunc*      = proc (ctx:RouteContext): RouteResult
    RouteHandler*   = proc (f:RouteFunc): RouteFunc
    RouteContext*   = ref object
        request*    : IRouteRequest
        response*   : RouteResponse
        urlParams*  : Table[string, string]
    
# next bind
proc `>=>`*(h1,h2: RouteHandler): RouteHandler =
    return proc(final: RouteFunc): RouteFunc =
        let f2 = h2 final
        let f1 = h1 f2
        return proc(ctx: RouteContext): RouteResult = 
            return f1 ctx

# end of handler
proc final*(ctx: RouteContext): RouteResult {.procvar.} =
    return RouteResult.find

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
