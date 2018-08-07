# depend on asynchttpserver is only this  
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
    context

proc final*(ctx: RouteContext): RouteResult {.procvar.} =
    return RouteResult.find
    
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


proc defaultErrorHandler(ex: ref Exception): RouteHandler =
    handler(ctx) do: return ctx.resp(Http500, "Internal Server Error")

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
proc routing*(router: Router, req: Request): Future[void] {.gcsafe.} =
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
        middlewares     : router.middlewares,
    )
    var errorHandler = router.errorHandler
    if errorHandler == nil:
        errorHandler = defaultErrorHandler

    try:
        let before = filter(router.middlewares.map do (m:Middleware) -> RouteHandler: m.before
                        , proc (h: RouteHandler): bool = h != nil)
                        .foldl(a >=> b, through)
        let after = filter(router.middlewares.map do (m:Middleware) -> RouteHandler: m.after
                        , proc (h: RouteHandler): bool = h != nil)
                        .foldl(a >=> b, through)
        
        let handler = before >=> router.handler

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


    