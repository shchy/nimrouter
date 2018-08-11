import 
    unittest,
    uri,
    strutils,
    tables,
    sequtils,
    os,
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
                GET >=> route("/") >=> text "hello",
                GET >=> route("/html") >=> html "world",
                GET >=> route("/code") >=> code Http400,
                GET >=> route("/resp") >=> resp(Http500, "world"),
                GET >=> route("/redirect") >=> redirect "/asdf",
                GET >=> routep("/getfile/{ file:string }") >=> (handler(ctx) do: ctx.sendfile(os.getAppDir() & "/assets/" & ctx.req.getUrlParam("file"))),
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

suite "test handler":
    let passWithTestHeader = handler(ctx, next) do: 
        ctx.setHeader("next", "pass")
        next ctx
    let hello = handler(ctx) do:
        ctx.text "hello"
    let world = handler(ctx) do:
        ctx.text "world"
    let filterBy = filter(rf(ctx) do: 
        not isNilOrWhitespace ctx.getHeader("notSet") )
    let abort = handler(ctx) do: RouteResult.none

    let handler =
            choose(
                route("/") >=> filterBy >=> world,
                route("/") >=> hello,
                route("/next") >=> passWithTestHeader >=> hello,
                route("/chooseAbortDoResetHeader") >=> passWithTestHeader >=> abort,
                route("/chooseAbortDoResetHeader") >=> hello,
                subRoute("/sub/", [
                    route("/") >=> world,
                    routep("/{id : int}") >=> (handler(ctx) do: ctx.text ctx.req.getUrlParam "id"),
                ]),
                route("/method/") >=> choose(
                    GET     >=> text "get",
                    HEAD    >=> text "head",
                    POST    >=> text "post",
                    PUT     >=> text "put",
                    DELETE  >=> text "delete",
                    PATCH   >=> text "patch",
                    TRACE   >=> text "trace",
                    OPTIONS >=> text "options",
                    CONNECT >=> text "connect",
                ),
                routep("/{id : int}/{name:string}/asdf/{v:float}") >=> (handler(ctx) do:
                                                                            let id = ctx.req.getUrlParam "id" 
                                                                            let name = ctx.req.getUrlParam "name"
                                                                            let v = ctx.req.getUrlParam "v"
                                                                            ctx.text ( "id=" & id & "name=" & name & "v=" & v)),
                route("/cache/") >=> asCacheable(proc():string ="etag") >=> text "cache me",
                serveDir("/static/", "./assets/")
            )
    let router = newRouter(handler)

    test "filter":
        let context = router.routingTest(HttpGet, "/")
        check(context.res.body == "hello")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)

    test "next bind":
        let context = router.routingTest(HttpGet, "/next")
        check(context.res.body == "hello")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(context.res.headers["next"] == "pass")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "chooseAbortDoResetHeader":
        let context = router.routingTest(HttpGet, "/chooseAbortDoResetHeader")
        check(context.res.body == "hello")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(not context.res.headers.hasKey "next")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "get":
        let context = router.routingTest(HttpGet, "/method/")
        check(context.res.body == "get")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "head":
        let context = router.routingTest(HttpHead, "/method/")
        check(context.res.body == "head")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "post":
        let context = router.routingTest(HttpPost, "/method/")
        check(context.res.body == "post")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "put":
        let context = router.routingTest(HttpPut, "/method/")
        check(context.res.body == "put")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "delete":
        let context = router.routingTest(HttpDelete, "/method/")
        check(context.res.body == "delete")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "patch":
        let context = router.routingTest(HttpPatch, "/method/")
        check(context.res.body == "patch")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "trace":
        let context = router.routingTest(HttpTrace, "/method/")
        check(context.res.body == "trace")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "options":
        let context = router.routingTest(HttpOptions, "/method/")
        check(context.res.body == "options")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "connect":
        let context = router.routingTest(HttpConnect, "/method/")
        check(context.res.body == "connect")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "urlParams":
        let context = router.routingTest(HttpGet, "/1985/aya/asdf/9.3")
        check(context.res.body == "id=1985name=ayav=9.3")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "subRoute":
        let context = router.routingTest(HttpGet, "/sub/")
        check(context.res.body == "world")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "subRouteWithParams":
        let context = router.routingTest(HttpGet, "/sub/01234")
        check(context.res.body == "01234")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)
    test "cache":
        let context = router.routingTest(HttpGet, "/cache/")
        check(context.res.body == "cache me")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(context.res.headers["etag"] == "etag")
        check(isNilOrWhitespace context.res.contentFilePath)
        let context2 = router.routingTest(HttpGet, "/cache/", "", (key:"If-None-Match", value:"etag"))
        check(context2.res.code == Http304)
        check(context2.res.headers["etag"] == "etag")
        check(isNilOrWhitespace context2.res.contentFilePath)
    test "staticFiles":
        let context = router.routingTest(HttpGet, "/static/test.txt")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(context.res.contentFilePath == os.getAppDir() & "/assets/test.txt")
        let etag = context.res.headers["etag"]
        let context2 = router.routingTest(HttpGet, "/static/test.txt", "", (key:"If-None-Match", value : $etag))
        check(context2.res.code == Http304)
        check(context2.res.headers["etag"] == $etag)
        check(isNilOrWhitespace context2.res.contentFilePath)
    
