import 
    unittest,
    strutils,
    tables,
    os,
    testcommon,
    ../src/alpaka


suite "test context":
    let handler = choose(
        GET >=> choose(
            route("/") >=> text "hello",
            route("/html") >=> html "world",
            route("/code") >=> code Http400,
            route("/resp") >=> resp(Http500, "world"),
            route("/redirect") >=> redirect "/asdf",
            routep("/getfile/{ file:string }") >=> (handler(ctx) do: ctx.sendfile(os.getAppDir() & "/assets/" & ctx.req.getUrlParam("file"))),
            route("/header") >=> 
                (handler(ctx) do: 
                    let value = ctx.getHeader("test")
                    ctx.setHeader("test", value)
                    let notSet = ctx.getHeader("notSet")
                    ctx.setHeader("notSet", notSet)
                    ctx.html "copy header"),
            route("/cookie") >=> 
                (handler(ctx) do: 
                    let value = ctx.getCookie("test")
                    ctx.setCookie("test", value)
                    ctx.setCookie("test1", value, 1000)
                    ctx.setCookie("test2", value, 1000, true)
                    ctx.setCookie("test3", value, 1000, true, true)
                    ctx.setCookie("test4", value, 1000, true, true, "/test/")
                    ctx.html "copy cookie"),
            route("/param") >=> (handler(ctx) do: ctx.text (ctx.req.getQueryParam "id")),
        ),
        POST >=> choose(
            route("/param") >=> (handler(ctx) do: ctx.text (ctx.req.getFormParam "id")),
        )
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
    test "code":
        let context = router.routingTest(HttpGet, "/code")
        check(context.res.body == "")
        check(context.res.code == Http400)
        check(not context.res.headers.hasKey "content-type")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "resp":
        let context = router.routingTest(HttpGet, "/resp")
        check(context.res.body == "world")
        check(context.res.code == Http500)
        check(not context.res.headers.hasKey "content-type")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "redirect":
        let context = router.routingTest(HttpGet, "/redirect")
        check(context.res.body == "")
        check(context.res.code == Http302)
        check(context.res.headers["location"] == "/asdf")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "sendfile":
        let context = router.routingTest(HttpGet, "/getfile/test.txt")
        check(context.res.body == "")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(context.res.contentFilePath == os.getAppDir() & "/assets/" & "test.txt")
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
    test "queryParam":
        let context = router.routingTest(HttpGet, "/param?id=aya")
        check(context.res.body == "aya")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "formParam":
        let context = router.routingTest(HttpPost, "/param", "id=aya")
        check(context.res.body == "aya")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
