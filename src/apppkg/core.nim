import 
    httpcore,
    uri,
    asynchttpserver,
    asyncdispatch

# Router Types
type
    IRouteRequest* = tuple[
        reqMethod: HttpMethod,
        headers: HttpHeaders,
        url: Uri,
        body: string
    ]
    RouteResponse*  = ref object
        code*:      HttpCode
        headers*:   HttpHeaders
        body*:      string
    RouteContext*   = ref object
        request*:   IRouteRequest
        response*:  RouteResponse   
    RouteResult*    = ref object
        context*:   RouteContext
    RouteFunc*      = proc (ctx:RouteContext): RouteResult
    RouteHandler*   = proc (f:RouteFunc): RouteFunc
    Router*         = ref object
        handler:            RouteHandler
        notFoundHandler:    RouteHandler


# create router
proc newRouter*(handler: RouteHandler, notFoundHandler: RouteHandler): Router =
    result = Router(
        handler: handler,
        notFoundHandler: notFoundHandler
    )


# end of handler
proc final(ctx: RouteContext): RouteResult =
    return RouteResult(context:ctx)


# routing for request
# asynchttpServer
proc routing*(router: Router, req: Request): Future[void] =
    let ctx = RouteContext(
        request:    ( 
            reqMethod:  req.reqMethod,
            headers:    req.headers,
            url:        req.url,
            body:       req.body
        ),
        response:   RouteResponse(
            code:       Http500,
            headers:    newHttpHeaders(),
            body:       ""
        )
    )
    var res = (router.handler final) ctx
    if res == nil:
        res = (router.notFoundHandler final) ctx
    
    if res == nil:
        return req.respond(Http500, "Internal Server Error")

    return req.respond(
        res.context.response.code
        , res.context.response.body
        , res.context.response.headers
    )
    

