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

suite "testblock":
    let handler =
            choose(
                GET >=> route("/") >=> (handler(ctx) do: ctx.text "hello"),
                GET >=> route("/method") >=> (handler(ctx) do: ctx.text "method"),
                GET >=> route("/controller/method") >=> (handler(ctx) do: ctx.html "controllerMethod"),
            )
    let router = newRouter(handler)
    
    test "test00":
        let context = makeCtx(HttpGet, "/")
        discard router.routing(context)
        check(context.res.body == "hello")
