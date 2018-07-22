import 
    asynchttpserver, 
    asyncdispatch,
    sequtils

type
    RouteHandler* = proc (req:Request): Future[void]
    Route* = ref object of RootObj
        httpMethod*:        HttpMethod
        path*:              string
        handler*:           RouteHandler
    Router* = ref object of RootObj
        routes:             seq[Route]
        notFoundHandler:    RouteHandler

proc newRouter*(notFoundHandler: RouteHandler, routes: varargs[Route]): Router =
    result = Router(
        routes: @routes,
        notFoundHandler: notFoundHandler
    )

proc routing*(router: Router, req:Request) {.async.} =
    let filterdByPath       = router.routes.filter(proc (r:Route): bool = r.path == req.url.path )
    let filterdByMethod     = filterdByPath.filter(proc (r:Route): bool = r.httpMethod == req.reqMethod)
    if filterdByMethod.len == 0 :
        await router.notFoundHandler req
    else :
        await filterdByMethod[0].handler req

proc get*(path: string, handler: RouteHandler): Route =
    return Route(
        path: path,
        httpMethod: HttpGet,
        handler: handler
    )
proc post*(path:string, handler: RouteHandler): Route =
    return Route(
        path:path,
        httpMethod: HttpPost,
        handler: handler
    )
