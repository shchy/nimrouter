import 
    httpcore,
    asyncdispatch,
    asynchttpServer,
    tables,
    uri,
    os,
    asyncnet,
    streams,
    sequtils
import
    ../core/context,
    router

type
    Server  = ref object of Middleware
        discard
    
const FILE_READ_BUFFER_SIZE: int = 1024 * 1024 * 16

proc sendFile(req: Request, code: HttpCode, headers: HttpHeaders, filePath: string) {.async.} =
    var head = "HTTP/1.1 " & $code & "\c\L"
    for k,v in headers:
        head.add(k & ": " & v & "\c\L")
    head.add("\c\L")
    await req.client.send(head)

    let file = newFileStream(filePath, FileMode.fmRead)
    var buffer : array[FILE_READ_BUFFER_SIZE, byte]
    var bp = addr buffer
    while not file.atEnd():
        let readedSize = file.readData(bp, buffer.len())
        await req.client.send(bp, readedsize)
    file.close()

proc bindContextToResponse(req: Request, ctx: RouteContext): Future[void] {.gcsafe.} =
    
    if existsFile ctx.res.contentFilePath:
        return sendFile(req, ctx.res.code, ctx.res.headers, ctx.res.contentFilePath)
    
    if ctx.res.body == nil:
        ctx.res.body = ""
    
    return req.respond(
        ctx.res.code
        , ctx.res.body
        , ctx.res.headers
    )

# routing for request
# asynchttpServer
proc bindAsyncHttpServer*(router: Router, req: Request): Future[void] {.gcsafe.} =
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
    
    try:
        let res = router.routing(ctx)
        if res == nil:
            return req.respond(Http404, "404 NotFound")
        
        return req.bindContextToResponse(ctx)
    except:
        return req.respond(Http500, "Internal Server Error")
        
proc run(router: Router, port: int): void =

    # bind router to asynchttpserver
    proc cb(req:Request) {.async.} =
        await router.bindAsyncHttpServer(req)

    let server = newAsyncHttpServer()
    waitfor server.serve(Port(port), cb)

proc useAsyncHttpServer*(router: Router, port: int): Router =
    let middleware = Server(
        run         : proc():void =run(router, port)
    )
    router.addMiddleware(middleware)
    return router
