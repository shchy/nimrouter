import 
    unittest,
    uri,
    strutils,
    tables,
    sequtils,
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
                GET >=> route("/cookie") >=> 
                    (handler(ctx) do: 
                        let value = ctx.getCookie("test")
                        ctx.setCookie("test", value)
                        ctx.setCookie("test1", value, 1000)
                        ctx.setCookie("test2", value, 1000, true)
                        ctx.setCookie("test3", value, 1000, true, true)
                        ctx.setCookie("test4", value, 1000, true, true, "/test/")
                        ctx.html "copy cookie"),
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
        check(context.res.headers.table["set-cookie"].contains("test=qwerty"))
        check(context.res.headers.table["set-cookie"].contains("test1=qwerty; Max-Age=1000"))
        check(context.res.headers.table["set-cookie"].contains("test2=qwerty; Max-Age=1000; secure"))
        check(context.res.headers.table["set-cookie"].contains("test3=qwerty; Max-Age=1000; secure; httponly"))
        check(context.res.headers.table["set-cookie"].contains("test4=qwerty; Max-Age=1000; secure; httponly; Path=/test/"))
        check(isNilOrWhitespace context.res.contentFilePath)
    