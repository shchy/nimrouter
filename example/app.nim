import 
    asynchttpserver, 
    asyncdispatch,
    htmlgen,
    httpcore,
    os
import 
    alpaka

proc main() =

    # handlers
    proc index(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext) : RouteResult =
            echo "hello"
            return ctx.text html(
                h1 "hello",
                a(href="/", "root")
            )

    proc world(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            echo "world"
            return ctx.text html(
                    h1 "world",
                    a(href="/test/", "test")
                )

    proc sleepTest(f : RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            echo "sleep"
            sleep 1000 * 1
            echo "wakeup"
            return f ctx

    proc notfound(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext) : RouteResult =
            return ctx.resp(Http404, h1 "404")

    proc setHeader(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            ctx.setHeader("test", "test")
            return next ctx
    
    proc redirectTest(ctx: RouteContext): RouteResult =
        ctx.redirect "/"

    proc args(i: int, next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            return ctx.text($i)

    let debugAborting = filter(proc(ctx: RouteContext): bool = false)

    # setting route
    var handler = 
        choose(
            get >=> setHeader >=>
                choose(
                    route("/")          >=> debugAborting                               >=> index,
                    route("/")          >=> asCacheable(proc():string="world", 60 * 5)  >=> world,
                    route("/test/")     >=> asCacheable(proc():string="sleep", 60 * 5)  >=> sleepTest   >=> index,
                    route("/redirect/") >=> wrap(redirectTest),
                    route("/hello/")    >=> text "hello, world",
                    route("/code/")     >=> code Http200,
                    routef("/format/",  args)

                )
        )
    var r = newRouter(handler, notfound)
    
    # bind router to asynchttpserver
    proc cb(req:Request) {.async, gcsafe.} =
        await r.routing(req)

    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()
