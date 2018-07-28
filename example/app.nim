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
            return ctx.text html(
                h1 "index",
                form(action="/post/", `method`="POST",
                    input(`type`="text", name="name"),
                    input(`type`="radio", name="sex", value="male"),
                    input(`type`="radio", name="sex", value="female"),
                    input(`type`="submit", value="send")
                )
                #a(href="/", "root")
            )
    proc postTest(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            let name = ctx.req.getFormParam "name"
            let sex = ctx.req.getFormParam "sex"
            return ctx.text html(
                name,
                sex 
            )

    proc world(f: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            return ctx.text html(
                    h1 "world",
                    a(href="/test/", "test")
                )

    proc sleepTest(f : RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            sleep 1000 * 1
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
            return ctx.text(ctx.req.getUrlParam("test"))

    proc queryParamtest(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            let p1 = ctx.req.getQueryParam "p1"
            let p2 = ctx.req.getQueryParam "p2"
            return ctx.text p1 & "&" & p2


    let debugAborting = filter(proc(ctx: RouteContext): bool = false)

    # setting route
    var handler = 
        choose(
            get     >=> setHeader   >=>
                choose(
                    route("/")                          >=> index,
                    route("/hello")                     >=> asCacheable(proc():string="world", 60 * 5)  >=> text "hello",
                    route("/world/")                    >=> asCacheable(proc():string="sleep", 60 * 5)  >=> sleepTest   >=> world,
                    route("/redirect/")                 >=> redirect "/",
                    route("/helloworld/")               >=> debugAborting >=> text "not work",
                    route("/helloworld/")               >=> text "hello, world",
                    route("/code/")                     >=> code Http200,
                    routep("/asdf/{test : int}/")       >=> debugAborting >=> urlParamTest,
                    routep("/asdf/{test2 : int}/")      >=> urlParamTest,
                    routep("/asdf/{test3 : string}")    >=> wrap(proc(ctx: RouteContext): RouteResult = ctx.text(ctx.req.getUrlParam("test3") ))
                ),
            route("/ping/") >=>
                get                                     >=> text "pong",
            route("/query")                             >=> queryParamtest,
            post    >=>
                route("/post/")                         >=> postTest,
            serveDir("/static/", "./static/"),
            notfound                                    >=> notfoundHandler
        )
    var r = Router(handler: handler)
    

    # bind router to asynchttpserver
    proc cb(req:Request) {.async, gcsafe.} =
        await r.routing(req)

    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()
