import 
    asynchttpserver, 
    asyncdispatch,
    sequtils


# Router Types
type
    RouteResult* = ref object of RootObj
        request*:           Request
    RouteFunc* = proc (req:Request): RouteResult
    RouteHandler* = proc (f:RouteFunc): RouteFunc
    # Route* = ref object of RootObj
    #     httpMethod*:        HttpMethod
    #     path*:              string
    #     handler*:           RouteHandler
    Router* = ref object of RootObj
        handler:            RouteHandler
        notFoundHandler:    RouteHandler

let abort*:RouteResult = nil

proc isMatchMethod(isMatch:proc(httpMethod:HttpMethod): bool): RouteHandler =
    return proc(f:RouteFunc): RouteFunc = 
        return proc(req:Request): RouteResult =
            if isMatch req.reqMethod:
                return f req
            else:
                return abort

let get*    = isMatchMethod(proc(m:HttpMethod):bool = m == HttpGet)
let post*   = isMatchMethod(proc(m:HttpMethod):bool = m == HttpPost)


proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    return proc(req: Request): RouteResult =
        if funcs.len == 0:
            return nil
        else:
            let res = funcs[0] req
            if res != nil:
                return res
            else:
                let f = chooseFuncs funcs[1..funcs.len-1]
                return f req

proc choose*(handlers:seq[RouteHandler]): RouteHandler =
    return proc(f: RouteFunc): RouteFunc =
        let funcs = handlers.map(proc(h:RouteHandler):RouteFunc = h f)
        return proc(req: Request): RouteResult =
            return chooseFuncs(funcs) req

# router
proc newRouter*(handler: RouteHandler, notFoundHandler: RouteHandler): Router =
    result = Router(
        handler: handler,
        notFoundHandler: notFoundHandler
    )

proc start(req:Request): RouteResult =
    return RouteResult(request:req)
    

proc terminate(req: Request, h: RouteHandler): Future[void] =
    discard (h start) req

proc `>=>`*(h1,h2: RouteHandler): RouteHandler =
    return proc(f: RouteFunc): RouteFunc =
        let f2 = h2 f
        let f1 = h1 f2
        return proc(req: Request): RouteResult = 
            return f1 req

proc routingSync(router: Router, req: Request): Future[void] =
    let res = (router.handler start) req
    if res == nil:
        discard terminate(req, router.notFoundHandler)
    

proc routing*(router: Router, req:Request) {.async.} =
    await router.routingSync(req)
    