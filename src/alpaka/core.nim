import 
    httpcore,
    uri,
    tables,
    sequtils,
    strutils,
    mimetypes,
    os
import
    request,
    response,
    params,
    types
    
export
    request,
    response,
    params,
    types
    

let mimeDB = newMimetypes()
# 
let abort* = RouteResult.none

proc through*(next: RouteFunc): RouteFunc {.procvar.} =
    return proc(ctx: RouteContext): RouteResult =
        return next ctx

# next bind
proc `>=>`*(h1,h2: RouteHandler): RouteHandler =
    return proc(final: RouteFunc): RouteFunc =
        let f2 = h2 final
        let f1 = h1 f2
        return proc(ctx: RouteContext): RouteResult = 
            return f1 ctx

# end of handler
proc final*(ctx: RouteContext): RouteResult {.procvar.} =
    return RouteResult.find

proc setHeader*(ctx: RouteContext, key, val: string): void =
    ctx.res.headers.add(key, val)

proc getHeader*(ctx: RouteContext, key: string): string =
    return ctx.req.headers.getOrDefault(key)

### context utils
proc resp*(ctx: RouteContext, code: HttpCode, content: string): RouteResult =
    ctx.res.code = code
    ctx.res.body = content
    return RouteResult.find

proc code*(ctx: RouteContext, code: HttpCode): RouteResult =
    ctx.res.code = code
    return RouteResult.find
    
proc text*(ctx: RouteContext, content: string): RouteResult =
    var mime = mimeDB.getMimeType("text")
    ctx.setHeader("Content-Type", mime)
    return ctx.resp(Http200, content)

proc html*(ctx: RouteContext, content: string): RouteResult =
    var mime = mimeDB.getMimeType("html")
    ctx.setHeader("Content-Type", mime)
    return ctx.resp(Http200, content)
    
proc redirect*(ctx: RouteContext, path: string, code: HttpCode = Http302 ): RouteResult =
    ctx.setHeader("Location", path)
    return ctx.code code

proc sendfile*(ctx: RouteContext, filePath: string): RouteResult =
    if not existsFile(filePath):
        return abort 
    if not os.getFilePermissions(filePath).contains(os.fpOthersRead):
        return ctx.code Http403
    let ext = (filePath).splitFile.ext
    let mime = mimeDB.getMimeType(ext[1..ext.len()-1])
    let fileSize = os.getFileSize(filePath)
    
    ctx.setHeader("Content-Type", mime)
    ctx.setHeader("Content-Length", $fileSize)
    ctx.res.contentFilePath = filePath
    ctx.res.code = Http200
    return RouteResult.find

proc withSubRoute*(ctx: RouteContext, path: string): string =
    if strutils.isNilOrWhitespace ctx.subRouteContext:
        return path
    return ctx.subRouteContext.joinPath path
proc updateSubRoute*(ctx: RouteContext, path: string) =
    ctx.subRouteContext = ctx.withSubRoute path
        
