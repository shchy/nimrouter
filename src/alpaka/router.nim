import 
    httpcore,
    asyncdispatch,
    asynchttpServer,
    tables,
    uri
import
    core

type
    Router*     = ref object
        handler*        : RouteHandler


# routing for request
# asynchttpServer
proc routing*(router: Router, req: Request): Future[void] =
    let ctx = RouteContext(
        request         : IRouteRequest( 
            reqMethod   : req.reqMethod,
            headers     : req.headers,
            url         : req.url,
            body        : req.body,
            urlParams   : newParams()
        ),
        response        : RouteResponse(
            code        : Http500,
            headers     : newHttpHeaders(),
            body        : ""
        )
    )
    var res = (router.handler final) ctx
    
    if res == RouteResult.none:
        return req.respond(Http500, "Internal Server Error")

    if ctx.response.body == nil:
        ctx.response.body = ""
        
    return req.respond(
        ctx.response.code
        , ctx.response.body
        , ctx.response.headers
    )
    

