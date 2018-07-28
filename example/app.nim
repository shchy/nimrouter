import 
    asynchttpserver, 
    asyncdispatch,
    htmlgen,
    httpcore,
    os,
    tables
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

    proc notfoundHandler(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext) : RouteResult =
            return ctx.resp(Http404, h1 "404")

    proc setHeader(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            ctx.setHeader("test", "test")
            return next ctx
    
    proc urlParamTest(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            return ctx.text(ctx.request.getUrlParam("test"))

    proc queryParamtest(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            let p1 = ctx.request.getQueryParam "p1"
            let p2 = ctx.request.getQueryParam "p2"
            return ctx.text p1 & "&" & p2


    let debugAborting = filter(proc(ctx: RouteContext): bool = false)

    # setting route
    var handler = 
        choose(
            get     >=> setHeader   >=>
                choose(
                    route("/")                          >=> debugAborting >=> index,
                    route("/")                          >=> asCacheable(proc():string="world", 60 * 5)  >=> world,
                    route("/test/")                     >=> asCacheable(proc():string="sleep", 60 * 5)  >=> sleepTest   >=> index,
                    route("/redirect/")                 >=> redirect "/",
                    route("/hello/")                    >=> text "hello, world",
                    route("/code/")                     >=> code Http200,
                    routep("/asdf/{test : int}/")       >=> debugAborting >=> urlParamTest,
                    routep("/asdf/{test2 : int}/")      >=> urlParamTest,
                    routep("/asdf/{test3 : string}")    >=> wrap(proc(ctx: RouteContext): RouteResult = ctx.text(ctx.request.getUrlParam("test3") ))
                ),
            route("/ping/") >=>
                get                                     >=> text "pong",
            route("/query")                             >=> queryParamtest,
            notfound                                    >=> notfoundHandler
        )
    var r = Router(handler: handler)
    

    # bind router to asynchttpserver
    proc cb(req:Request) {.async, gcsafe.} =
        await r.routing(req)

    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()
