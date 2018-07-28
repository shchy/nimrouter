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
    core,
    utils

# varargs to seq
proc `@`[T](xs:openArray[T]): seq[T] = 
    var s: seq[T] = @[]
    for x in xs:
        s.add x
    return s

proc through(next: RouteFunc): RouteFunc =
    return proc(ctx: RouteContext): RouteResult =
        return next ctx

# choose func until not abort
proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    return proc(ctx: RouteContext): RouteResult =
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
        return proc(ctx: RouteContext): RouteResult =
            return chooseFuncs(funcs) ctx

### filters

# filter by context
proc filter*(isMatch:proc(ctx:RouteContext): bool): RouteHandler =
    return proc(next: RouteFunc): RouteFunc = 
        return proc(ctx:RouteContext): RouteResult =
            if isMatch ctx:
                return next ctx
            else:
                return abort

# all
let NOTFOUND*   = filter(proc(ctx: RouteContext): bool = true)

# httpmethod filter
let HEAD*       = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpHead)
let GET*        = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpGet)
let POST*       = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpPost)
let PUT*        = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpPut)
let DELETE*     = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpDelete)
let PATCH*      = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpPatch)
let TRACE*      = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpTrace)
let OPTIONS*    = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpOptions)
let CONNECT*    = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpConnect)

# path filter
proc route*(path: string): RouteHandler =
    return filter(proc(ctx: RouteContext): bool = ctx.req.url.path == ctx.withSubRoute path )

const urlParamRegex = r"{\s?(\w+?)\s?:\s?(int|string|float)\s?}"
# path filter with url parameter
# ex.
#   /user/{ id : string }
#   /blog/{year : int}/{ month : int }/{ day : int }/{ id : int}
proc routep*(path: string): RouteHandler =
    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
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
            
proc serveDir*(path,localPath: string, maxAge: int): RouteHandler =
    # todo path must be terminate "/"
    var localPath = localPath
    if not localPath.isAbsolute():
        localPath = $(parseUri(getAppDir()) / localPath.replace("./","") )
    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
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

proc subRoute*(path: string, handlers: openarray[RouteHandler]): RouteHandler =
    let hs = @handlers
    var handler : RouteHandler
    if hs.len() == 0:
        handler = through
    elif hs.len() == 1:
        handler = hs[0]
    else:
        handler = choose(hs)

    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            if not ctx.req.url.path.startsWith(ctx.withSubRoute path):
                return abort
            ctx.updateSubRoute path
            let f = handler next
            return f ctx