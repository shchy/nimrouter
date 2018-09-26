import 
    httpcore,
    sockets,
    httpServer,
    tables,
    uri,
    os,
    asyncnet,
    streams,
    sequtils,
    strutils,
    strtabs
import
    ../core/context,
    router

type
    HttpServer  = ref object of Middleware
        discard
    
const FILE_READ_BUFFER_SIZE: int = 1024 * 1024 * 16


proc resp(s: Server, code: HttpCode, content: string, headers: HttpHeaders = nil) =
    var head = "HTTP/1.1 " & $code & "\c\L"
    if headers != nil:
        for k,v in headers:
            head.add(k & ": " & v & "\c\L")
    head.add("\c\L")
    s.client.send(head)
    s.client.send(content)



proc sendFile(s: Server, code: HttpCode, headers: HttpHeaders, filePath: string) =
    var f: File
    if open(f, filePath) == false:
        s.resp(Http404, "not found")

    var head = "HTTP/1.1 " & $code & "\c\L"
    for k,v in headers:
        head.add(k & ": " & v & "\c\L")
    head.add("\c\L")
    s.client.send(head)

    const bufSize = 8000 # != 8K might be good for memory manager
    var buf = alloc(bufsize)
    while true:
        var bytesread = readBuffer(f, buf, bufsize)
        if bytesread > 0:
            var byteswritten = send(s.client, buf, bytesread)
            if bytesread != bytesWritten:
                dealloc(buf)
                close(f)
                raiseOSError(osLastError())
        if bytesread != bufSize: break
    dealloc(buf)
    close(f)

proc bindContextToResponse(s: Server, ctx: RouteContext) =
    
    if existsFile ctx.res.contentFilePath:
        sendFile(s, ctx.res.code, ctx.res.headers, ctx.res.contentFilePath)
        return 
    
    if ctx.res.body == nil:
        ctx.res.body = ""
    
    s.resp(
        ctx.res.code
        , ctx.res.body
        , ctx.res.headers
    )

# routing for request
# asynchttpServer
proc callback (router: Router, s: Server): bool {.procvar.} =
    try:
        let headers = newHttpHeaders()
        for item in s.headers.pairs:
            headers.add(item.key, item.value)
        let ctx = RouteContext(
            req             : RouteRequest( 
                reqMethod   : parseEnum[HttpMethod]("Http" & s.reqMethod),
                headers     : headers,
                url         : ( s.path & "?" & s.query).parseUri(),
                body        : s.body,
                urlParams   : newParams()
            ),
            res             : RouteResponse(
                code        : Http500,
                headers     : newHttpHeaders(),
                body        : ""
            )
        )

        let res = router.routing(ctx)
        if res == nil:
            s.resp(Http404, "404 NotFound")
        s.bindContextToResponse(ctx)
    except:
        s.resp(Http500, "Internal Server Error")
    return false


proc run(handleRequest: proc (server: Server): bool {.closure.}, port = Port(80)) =

    ## encapsulates the server object and main loop
    var s: Server
    s.open(port, reuseAddr = true)
    #echo("httpserver running on port ", s.port)
    while true:
        s.next()
        if handleRequest(s): break
        s.client.close()
    s.close()

proc proxy(router: Router, port: int): void =
    proc cb(server: Server): bool {.procvar.} =
        return router.callback(server)
    run(cb, Port(port))

proc useHttpServer*(router: Router, port: int): Router =
    let middleware = HttpServer(
        run         : proc():void =proxy(router, port)
    )
    router.addMiddleware(middleware)
    return router
