import 
  httpcore,
  uri,
  tables,
  sequtils,
  strutils,
  mimetypes,
  os,
  sugar
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
    id*   : string
    name*   : string
    role*   : seq[string]  
  RouteContext* = ref object
    req*      : RouteRequest
    res*      : RouteResponse
    user*       : AuthedUser
    middlewares*  : seq[Middleware]
    subRouteContext*: string
  Middleware* = ref object of RootObj
    run*  : proc():void
    before* : RouteHandler
    after*  : RouteHandler

let mimeDB = newMimetypes()

########## context procs

proc setHeader*(ctx: RouteContext, key, val: string): void =
  ctx.res.headers.add(key, val)

proc getHeader*(ctx: RouteContext, key: string): string =
  return ctx.req.headers.getOrDefault(key)

proc setCookie*(ctx: RouteContext, key, val: string, maxAge: int = 0, isSecure, isHttpOnly: bool = false, path: string = ""): void =
  var val = key & "=" & val
  if maxAge != 0:
    val.add("; Max-Age=" & $maxAge)
  if isSecure:
    val.add("; secure")
  if isHttpOnly:
    val.add("; httponly")
  if not path.isNilOrWhitespace:
    val.add("; Path=" & path)
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
  let mx = ctx.middlewares.filter( m => (m of T))
  if not mx.any(_ => true) :
    return nil
  return T(mx[0])

proc joinUrl(head,tail: string): string =
  var h = head
  var t = tail
  
  if h.endsWith("/"):
    h = h.substr(0, len(h)-2)
  if t.startsWith("/"):
    t = t.substr(1, len(t)-1)
  return h & "/" & t

proc withSubRoute*(ctx: RouteContext, path: string): string =
  if strutils.isNilOrWhitespace ctx.subRouteContext:
    return path
  return ctx.subRouteContext.joinUrl path

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
  
proc mime*(ctx: RouteContext, mimeType, content: string): RouteResult =
  var mime = mimeDB.getMimeType(mimeType)
  ctx.setHeader("Content-Type", mime)
  return ctx.resp(Http200, content)

proc text*(ctx: RouteContext, content: string): RouteResult =
  return ctx.mime("text", content)

proc html*(ctx: RouteContext, content: string): RouteResult =
  return ctx.mime("html", content)
  
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

proc sendView*(ctx: RouteContext, filePath: string): RouteResult =
  var localPath = filePath
  if not localPath.isAbsolute():
    localPath = joinPath($parseUri(getAppDir()), localPath)
  
  return ctx.sendfile($localPath)