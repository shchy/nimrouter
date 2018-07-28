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

# choose func until not abort
proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    return proc(ctx: RouteContext): RouteResult =
        if funcs.len == 0:
            return abort
        
        let tempResponse = ctx.res.clone()
        let tempUrlParams = ctx.req.urlParams.clone()
        let res = funcs[0] ctx
        if res != abort:
            return res
        
        # reset response
        ctx.res = tempResponse
        ctx.req.urlParams = tempUrlParams
        
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
let notfound*   = filter(proc(ctx: RouteContext): bool = true)

# httpmethod filter
let head*       = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpHead)
let get*        = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpGet)
let post*       = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpPost)
let put*        = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpPut)
let delete*     = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpDelete)
let patch*      = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpPatch)
let trace*      = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpTrace)
let options*    = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpOptions)
let connect*    = filter(proc(ctx:RouteContext):bool = ctx.req.reqMethod == HttpConnect)

# path filter
proc route*(path: string): RouteHandler =
    return filter(proc(ctx: RouteContext): bool = ctx.req.url.path == path )

const urlParamRegex = r"{\s?(\w+?)\s?:\s?(int|string|float)\s?}"
# path filter with url parameter
# ex.
#   /user/{ id : string }
#   /blog/{year : int}/{ month : int }/{ day : int }/{ id : int}
proc routep*(path: string): RouteHandler =
    let expectedSegments = path.split("/")

    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
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
            if not ctx.req.url.path.startsWith(path):
                return abort
            
            let reqFilePath = 
                ctx.req.url.path[path.len()..ctx.req.url.path.len()-1]
            let localFilePath = joinPath(localPath, reqFilePath)
            
            if not existsFile localFilePath:
                return abort
                
            let fileInfo = os.getFileInfo(localFilePath)
            let hash = md5.getMD5( localFilePath & $(fileInfo.lastWriteTime) )
            if ctx.isCached(hash, maxAge):
                return ctx.code(Http304)
            return ctx.sendFile(localFilePath)
