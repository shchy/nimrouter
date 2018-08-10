import 
    unittest,
    uri,
    strutils,
    ../src/alpaka


proc routingTest(router: Router, httpMethod: HttpMethod
                , path: string, body: string = ""
                , headers: varargs[tuple[key:string, value:string]] = @[]): RouteContext =

    let ctx = RouteContext(
        req             : RouteRequest( 
            reqMethod   : httpMethod,
            headers     : newHttpHeaders(),
            url         : parseUri "http://localhost:8080" & path,
            body        : body,
            urlParams   : newParams()
        ),
        res             : RouteResponse(
            code        : Http500,
            headers     : newHttpHeaders(),
            body        : ""
        ),
    )

    for item in headers:
        ctx.req.headers.add(item.key, item.value)
        
    router.routing(ctx)
    

suite "test context":
    let handler =
            choose(
                GET >=> route("/") >=> (handler(ctx) do: ctx.text "hello"),
                GET >=> route("/html") >=> (handler(ctx) do: ctx.html "world"),
                GET >=> route("/header") >=> 
                    (handler(ctx) do: 
                        let value = ctx.getHeader("test")
                        ctx.setHeader("test", value)
                        let notSet = ctx.getHeader("notSet")
                        ctx.setHeader("notSet", notSet)
                        ctx.html "copy header"),
                    # (handler(ctx) do: ctx.html "controllerMethod"),
            )
    let router = newRouter(handler)
    test "text":
        let context = router.routingTest(HttpGet, "/")
        check(context.res.body == "hello")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "html":
        let context = router.routingTest(HttpGet, "/html")
        check(context.res.body == "world")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/html")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "header":
        let context = router.routingTest(HttpGet, "/header", "", (key:"test", value: "asdfghjk"))
        check(context.res.body == "copy header")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/html")
        check(context.res.headers["test"] == "asdfghjk")
        check(isNilOrWhitespace context.res.headers["notSet"])
        check(isNilOrWhitespace context.res.contentFilePath)
    test "cookie":
        let context = router.routingTest(HttpGet, "/cookie", "", (key:"cookie", value: "test=qwerty"))
        check(context.res.body == "copy cookie")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/html")
        check(context.res.headers["set-cookie"] == "test=qwerty; max-age=1000; path=/test/")
        check(context.res.headers["set-cookie"] == "test=qwerty; max-age=1000; path=/test/")
        check(context.res.headers["set-cookie"] == "test2=qwerty; max-age=1000; path=/test/; secure")
        check(context.res.headers["set-cookie"] == "test3=qwerty; max-age=1000; path=/test/; secure; httponly")
        check(isNilOrWhitespace context.res.contentFilePath)
    