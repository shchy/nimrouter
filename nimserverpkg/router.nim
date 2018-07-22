import 
    asynchttpserver, 
    asyncdispatch,
    sequtils

type
    Route* = ref object of RootObj
        httpMethod*:        HttpMethod
        path*:              string
        handler*:           proc (req:Request): Future[void]
    Router* = ref object of RootObj
        routes:             seq[Route]
        notFoundHandler:    proc (req: Request): Future[void]

proc newRouter*(notFoundHandler: proc (req: Request): Future[void]
                , routes: varargs[Route]): Router =
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