import 
    asynchttpserver, 
    htmlgen,
    httpcore,
    os
import 
    ../../src/alpaka

proc main() =
    # handlers
    let index = handler(ctx) do:
        ctx.html html(
            h1 "index",
            form(action="/post/", `method`="POST",
                input(`type`="text", name="name"),
                input(`type`="radio", name="sex", value="male"),
                input(`type`="radio", name="sex", value="female"),
                input(`type`="submit", value="send")
            )
            #a(href="/", "root")
        )
    let postTest = handler(ctx) do:
        let name = ctx.req.getFormParam "name"
        let sex = ctx.req.getFormParam "sex"
        return ctx.html html(
            name,
            sex 
        )
    let hello = handler(ctx) do:
        echo "hello"
        return ctx.html html(
            h1 "hello",
            a(href="/world/", "world")
        )

    let world = handler(ctx) do:
        echo "world"
        return ctx.html html(
                h1 "world",
                a(href="/hello/", "hello"),
                img(src="/static/sample.jpg", alt="alt")
            )

    let sleepTest = handler(ctx, next) do:
        sleep 1000 * 10
        return next ctx

    let notfoundHandler = handler(ctx) do:
        ctx.resp(Http404, h1 "404")

    let setHeader = handler(ctx, next) do:
        ctx.setHeader("test", "test")
        return next ctx
    
    let urlParamTest = handler(ctx) do:
        ctx.text(ctx.req.getUrlParam("test"))

    let queryParamtest = handler(ctx) do:
        let p1 = ctx.req.getQueryParam "p1"
        let p2 = ctx.req.getQueryParam "p2"
        return ctx.text p1 & "&" & p2


    let debugAborting = filter(proc(ctx: RouteContext): bool = false)

    let errorHandler = 
        proc(ex: ref Exception): RouteHandler =
            handler(ctx) do: ctx.resp( Http500, "Exception!")

    # setting route
    var handler = 
        choose(
            GET >=> setHeader >=>
                choose(
                    route("/")                          >=> index,
                    route("/hello/")                    >=> asCacheable(proc():string="hello", 60)  >=> hello,
                    route("/world/")                    >=> asCacheable(proc():string="world", 60)  >=> world,
                    route("/sleep")                     >=> asCacheable(proc():string="sleep", 60)  >=> sleepTest >=> text "wakeup",
                    route("/redirect/")                 >=> redirect "/",
                    route("/helloworld/")               >=> debugAborting >=> text "not work",
                    route("/helloworld/")               >=> text "hello, world",
                    route("/code/")                     >=> code Http200,
                    routep("/asdf/{test : int}/")       >=> debugAborting >=> urlParamTest,
                    routep("/asdf/{test2 : int}/")      >=> urlParamTest,
                    routep("/asdf/{test3 : string}")    >=> (handler(ctx) do: ctx.text(ctx.req.getUrlParam("test3"))), 
                    routep("/asdf/{test4 : float}")     >=> (handler(ctx) do: ctx.text(ctx.req.getUrlParam("test4"))) 
                ),
            route("/ping/") >=>
                GET                                     >=> text "pong",
            route("/query")                             >=> queryParamtest,
            POST    >=>
                route("/post/")                         >=> postTest,
            # static file serve
            GET                                         >=> serveDir("/static/", "./static/", 60),
            # sub module
            subRoute("/sub",[
                route("/abc/")                          >=> text "sub Route"
            ]),
            subRoute("/sub/",[ 
                route("/test/")                         >=> text "test",
                subRoute("/sub3/",[ 
                    route("/")                          >=> text "sub3",
                    routep("/{aaa : int}")              >=> (handler(ctx) do: ctx.text( ctx.req.getUrlParam("aaa") )) 
                ])
            ]),
            route("/error/")                            >=> (handler(_) do: raise newException(Exception, "testException")),
            NOTFOUND                                    >=> notfoundHandler
        )
    var r = newRouter(
        handler,
        errorHandler
    ).useAsyncHttpServer(8080, "0.0.0.0")

    r.run()
    

main()
