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
    params
    
export
    request,
    response,
    params
    
type
    RouteResult* = enum 
        none, 
        find 
    RouteFunc* = proc (ctx:RouteContext): RouteResult
    RouteHandler* = proc (f:RouteFunc): RouteFunc
    ErrorHandler* = proc (ex: ref Exception): RouteHandler
    AuthedUser* = ref object
        id*     : string
        name*   : string
        role*   : seq[string]  
    RouteContext* = ref object
        req*            : RouteRequest
        res*            : RouteResponse
        user*           : AuthedUser
        middlewares*    : seq[Middleware]
        subRouteContext*: string
    Middleware* = ref object of RootObj
        before* : RouteHandler
        after*  : RouteHandler

let mimeDB = newMimetypes()

########## context procs

proc setHeader*(ctx: RouteContext, key, val: string): void =
    ctx.res.headers.add(key, val)

proc getHeader*(ctx: RouteContext, key: string): string =
    return ctx.req.headers.getOrDefault(key)

proc setCookie*(ctx: RouteContext, key, val: string, maxAge: int, path: string, isSecure, isHttpOnly: bool): void =
    var val = key & "=" & val & "; Max-Age=" & $maxAge
    if not path.isNilOrWhitespace:
        val.add("; Path=" & path)
    if isSecure:
        val.add("; secure")
    if isHttpOnly:
        val.add("; httponly")
    
    ctx.setHeader("Set-Cookie", val)

proc getCookie*(ctx: RouteContext, key: string): string =
    let cookies = ctx.getHeader("Cookie").split(";").map do (v: string) -> string: v.strip
    result = ""
    for cookie in cookies:
        let kv = cookie.split("=")
        if kv.len != 2:
            continue
        if kv[0] == key:
            result = kv[1]
            break

proc getMiddleware*[T](ctx: RouteContext): T =
    let mx = ctx.middlewares.filter do (m:Middleware) -> bool: (m of T)
    if not mx.any(proc(m:Middleware):bool = true) :
        return nil
    return T(mx[0])
    
proc withSubRoute*(ctx: RouteContext, path: string): string =
    if strutils.isNilOrWhitespace ctx.subRouteContext:
        return path
    return ctx.subRouteContext.joinPath path
proc updateSubRoute*(ctx: RouteContext, path: string) =
    ctx.subRouteContext = ctx.withSubRoute path
        

########## end of handler
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
        return RouteResult.none 
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