import 
    unittest,
    uri,
    ../src/alpaka

proc makeCtx(httpMethod: HttpMethod, path: string, body: string = "" ): RouteContext =
    RouteContext(
            req             : RouteRequest( 
                reqMethod   : httpMethod,
                headers     : newHttpHeaders(),
                url         : parseUri "http://localhost:8080" & path,
                body        : "",
                urlParams   : newParams()
            ),
            res             : RouteResponse(
                code        : Http500,
                headers     : newHttpHeaders(),
                body        : body
            ),
        )
proc routingTest(router: Router, httpMethod: HttpMethod, path: string, body: string = ""): RouteContext =
    let ctx = makeCtx(httpMethod, path, body)
    router.routing(ctx)
    

suite "testblock":
    let handler =
            choose(
                GET >=> route("/") >=> (handler(ctx) do: ctx.text "hello"),
                GET >=> route("/method") >=> (handler(ctx) do: ctx.text "method"),
                GET >=> route("/controller/method") >=> (handler(ctx) do: ctx.html "controllerMethod"),
            )
    let router = newRouter(handler)
    
    test "route00":
        let context = router.routingTest(HttpGet, "/")
        check(context.res.body == "hello")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(context.res.contentFilePath == "")
    test "route01":
        let context = router.routingTest(HttpGet, "/method")
        check(context.res.body == "method")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(context.res.contentFilePath == "")
    test "route02":
        let context = router.routingTest(HttpGet, "/controller/method")
        check(context.res.body == "controllerMethod")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/html")
        check(context.res.contentFilePath == "")