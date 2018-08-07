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

const FILE_READ_BUFFER_SIZE: int = 1024 * 1024 * 16


type
    RouterOnAsyncHttpServer* = ref object of Router[Request]
        discard

proc final*(ctx: RouteContext): RouteResult {.procvar.} =
    return RouteResult.find
    

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

proc defaultErrorHandler(ex: ref Exception): RouteHandler =
    handler(ctx) do: return ctx.resp(Http500, "Internal Server Error")


# routing for request
# asynchttpServer
method routing*(this: Router, req: Request): Future[void] {.gcsafe, base.} =
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
        ),
        subRouteContext : "",
        middlewares     : this.middlewares,
    )
    var errorHandler = this.errorHandler
    if errorHandler == nil:
        errorHandler = defaultErrorHandler

    try:
        let before = filter(this.middlewares.map do (m:Middleware) -> RouteHandler: m.before
                        , proc (h: RouteHandler): bool = h != nil)
                        .foldl(a >=> b, through)
        let after = filter(this.middlewares.map do (m:Middleware) -> RouteHandler: m.after
                        , proc (h: RouteHandler): bool = h != nil)
                        .foldl(a >=> b, through)
        
        let handler = before >=> this.handler

        let res = (handler final) ctx

        if res == RouteResult.none:
            return req.respond(Http404, "404 NotFound")
        
        discard (after final) ctx
        
        return req.bindContextToResponse(ctx)
    except:
        let ex = getCurrentException()
        let msg = getCurrentExceptionMsg()
        echo "Exception" & repr(ex) & " message:" & msg

        if errorHandler == nil:
            return req.respond(Http500, "Internal Server Error")
        let handler = errorHandler ex
        let res = (handler final) ctx
        if res == RouteResult.none:
            return req.respond(Http500, "Internal Server Error")
                
        return req.bindContextToResponse(ctx)


        
