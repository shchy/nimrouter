import
    httpcore,
    strutils,
    sequtils,
    parseutils,
    tables,
    nre, options as opt,
    cgi,
    os, uri, md5, times
import 
    context

# varargs to seq
proc `@`[T](xs:openArray[T]): seq[T] = 
    var s: seq[T] = @[]
    for x in xs:
        s.add x
    return s

########## routing handlers

# choose func until not abort
proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    rf(ctx) do:
        if funcs.len == 0:
            return abort
        
        let tempResponse = ctx.res.clone()
        let tempUrlParams = ctx.req.urlParams.clone()
        let subRouteContext = ctx.subRouteContext
        let res = funcs[0] ctx
        if res != abort:
            return res
        
        # reset response
        ctx.res = tempResponse
        ctx.req.urlParams = tempUrlParams
        ctx.subRouteContext = subRouteContext
        
        # find other
        let f = chooseFuncs funcs[1..funcs.len-1]
        return f ctx

# choose handler until not abort
proc choose*(handlers: varargs[RouteHandler]): RouteHandler =
    var hx = @handlers
    return proc(final: RouteFunc): RouteFunc =
        var funcs = hx.map(proc(h:RouteHandler):RouteFunc = h final)
        rf(ctx) do:
            return chooseFuncs(funcs) ctx

# filter by context
proc filter*(isMatch: proc(ctx:RouteContext): bool): RouteHandler =
    handler(ctx, next) do :
        if isMatch ctx:
            return next ctx
        else:
            return abort

# all
let NOTFOUND*   = filter(rf(_) do: return true)

# httpmethod filter
let HEAD*       = filter(rf(ctx) do: return ctx.req.reqMethod == HttpHead)
let GET*        = filter(rf(ctx) do: return ctx.req.reqMethod == HttpGet)
let POST*       = filter(rf(ctx) do: return ctx.req.reqMethod == HttpPost)
let PUT*        = filter(rf(ctx) do: return ctx.req.reqMethod == HttpPut)
let DELETE*     = filter(rf(ctx) do: return ctx.req.reqMethod == HttpDelete)
let PATCH*      = filter(rf(ctx) do: return ctx.req.reqMethod == HttpPatch)
let TRACE*      = filter(rf(ctx) do: return ctx.req.reqMethod == HttpTrace)
let OPTIONS*    = filter(rf(ctx) do: return ctx.req.reqMethod == HttpOptions)
let CONNECT*    = filter(rf(ctx) do: return ctx.req.reqMethod == HttpConnect)


# path filter
proc route*(path: string): RouteHandler =
    return filter(rf(ctx) do: return ctx.req.url.path == ctx.withSubRoute path )

const urlParamRegex = r"{\s?(\w+?)\s?:\s?(int|string|float)\s?}"
# path filter with url parameter
# ex.
#   /user/{ id : string }
#   /blog/{year : int}/{ month : int }/{ day : int }/{ id : int}
proc routep*(path: string): RouteHandler =
    handler(ctx, next) do:
        let expectedSegments = (ctx.withSubRoute path).split("/")
        let segemnts = ctx.req.url.path.split("/")
        if expectedSegments.len() != segemnts.len():
            return abort
            
        let zipped = 
            expectedSegments.zip(segemnts)

        for zip in zipped:
            # expect is segemnt
            # , or expect is urlParam
            let expect = zip.a
            let segment = zip.b
            if expect == segment:
                continue

            let maybe = expect.match(re urlParamRegex)
            if maybe.isNone():
                return abort
                
            let match = opt.get maybe
            let captures = match.captures().toSeq()
            if captures.len() != 2:
                return abort
                
            let name = captures[0]
            let typeName = captures[1]
            
            try:
                case typeName:
                    of "int":
                        discard segment.parseInt()
                    of "float":
                        discard segment.parseFloat()
                    of "string":
                        discard
                    else: 
                        return abort    
                ctx.req.urlParams.setParam(decodeUrl name, decodeUrl segment)
            except:
                return abort
        return next ctx

proc subRoute*(path: string, handlers: openarray[RouteHandler]): RouteHandler =
    let hs = @handlers
    var h : RouteHandler
    if hs.len() == 0:
        h = through
    elif hs.len() == 1:
        h = hs[0]
    else:
        h = choose(hs)

    handler(ctx, next) do:
        if not ctx.req.url.path.startsWith(ctx.withSubRoute path):
            return abort
        ctx.updateSubRoute path
        let f = h next
        return f ctx

########## utils handlers 

# cacheable
proc isCached*(ctx: RouteContext, etag: string, maxAge: int): bool = 
    ctx.setHeader("Cache-Control", "max-age="& $maxage)
    ctx.setHeader("ETag", etag)
    let etagInHeader = ctx.getHeader("If-None-Match")
    return etagInHeader.contains(etag)

proc asCacheable*(getEtag: proc(): string, maxAge: int): RouteHandler =
    handler(ctx, next) do:
        let etag = getEtag()
        if ctx.isCached(etag, maxAge):
            return ctx.resp(Http304, "Not Modified")
        return next ctx

# not next wrapper
proc code*(code: HttpCode): RouteHandler = 
    handler(ctx) do: return ctx.code code
    
proc text*(content: string): RouteHandler = 
    handler(ctx) do: return ctx.text content

proc html*(content: string): RouteHandler = 
    handler(ctx) do: return ctx.html content
    
proc redirect*(location: string, code: HttpCode = Http302): RouteHandler = 
    handler(ctx) do: return ctx.redirect(location, code)


# file serve
proc serveDir*(path,localPath: string, maxAge: int): RouteHandler =
    # todo path must be terminate "/"
    var localPath = localPath
    if not localPath.isAbsolute():
        localPath = $(parseUri(getAppDir()) / localPath.replace("./","") )
    handler(ctx) do:
        let routePath = ctx.withSubRoute path
        if not ctx.req.url.path.startsWith(routePath):
            return abort
        
        let reqFilePath = 
            decodeUrl ctx.req.url.path[routePath.len()..ctx.req.url.path.len()-1]
        let localFilePath = joinPath(localPath, reqFilePath)
        
        if not localFilePath.startsWith localPath:
            return ctx.code Http403

        if not existsFile localFilePath:
            return abort
            
        let fileInfo = os.getFileInfo(localFilePath)
        let hash = md5.getMD5( localFilePath & $(fileInfo.lastWriteTime) )
        if ctx.isCached(hash, maxAge):
            return ctx.code(Http304)
        return ctx.sendFile(localFilePath)
