import 
    asynchttpserver, 
    asyncdispatch,
    htmlgen,
    os
import apppkg/router

proc main() =

    proc index(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext) : RouteResult =
            ctx.response.code = Http200
            ctx.response.body = h1 "hello"
            return RouteResult(context: ctx)

    proc sleepTest(f : RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            sleep 1000 * 10
            return RouteResult(context: ctx)

    proc notfound(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext) : RouteResult =
            ctx.response.code = Http404
            ctx.response.body = h1 "404"
            return RouteResult(context: ctx)

    var indexRoute = get >=> route("/") >=> index
    var debug = get >=> route("/test/") >=> sleepTest >=> index
    var a = get >=> index
    
    var handler = choose(@[indexRoute, debug, a])
    # var testRoute = get("/{i}", index)
    var r = newRouter(handler, notfound)
    
    proc cb(req:Request) {.async.} =
        await r.routing(req)
    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()
