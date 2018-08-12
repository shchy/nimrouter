import 
    ../src/alpaka,
    httpcore,
    uri
export
    httpcore,
    alpaka


proc routingTest*(router: Router, httpMethod: HttpMethod
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
    
