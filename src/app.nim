import 
    asynchttpserver, 
    asyncdispatch,
    htmlgen,
    httpcore,
    os
import apppkg/router


proc main() =
    # handlers
    proc index(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext) : RouteResult =
            return ctx.text h1 "hello"
            
    proc world(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            return ctx.text h1 "world"

    proc sleepTest(f : RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            sleep 1000 * 1
            return f ctx

    proc notfound(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext) : RouteResult =
            return ctx.resp(Http404, h1 "404")

    proc setHeader(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            ctx.response.headers.add("a", "b")
            return next ctx

    let debugAborting = filter(proc(ctx: RouteContext): bool = false)
    
    # setting route
    var handler = choose(@[
        get >=> setHeader >=>
            choose(@[
                route("/") >=> debugAborting >=> index,
                route("/") >=> world,
                route("/test/") >=> sleepTest >=> index
            ]),
    ])
    var r = newRouter(handler, notfound)
    

    # bind router to asynchttpserver
    proc cb(req:Request) {.async, gcsafe.} =
        await r.routing(req)

    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()
