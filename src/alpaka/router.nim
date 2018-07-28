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
    try:        
        let ctx = RouteContext(
            req             : RouteRequest( 
                reqMethod   : req.reqMethod,
                headers     : req.headers,
                url         : req.url,
                body        : req.body,
                urlParams   : newParams()
            ),
            res             : RouteResponse(
                code        : Http500,
                headers     : newHttpHeaders(),
                body        : ""
            )
        )
        var res = (router.handler final) ctx
        
        if res == RouteResult.none:
            return req.respond(Http404, "404 NotFound")

        if ctx.res.body == nil:
            ctx.res.body = ""
            
        return req.respond(
            ctx.res.code
            , ctx.res.body
            , ctx.res.headers
        )
    except:
        let ex = getCurrentException()
        let msg = getCurrentExceptionMsg()
        echo "Exception" & repr(ex) & " message:" & msg
        return req.respond(Http500, "Internal Server Error")
