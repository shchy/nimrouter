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

########## generate handler
template handler*(c, f, actions:untyped): untyped =
    var result = (
        proc (next: RouteFunc): RouteFunc =
            var f = next
            return proc(ctx: RouteContext): RouteResult =
                var c = ctx
                actions
    )
    result

template handler*(c, actions:untyped): untyped =
    var result = (
        proc (next: RouteFunc): RouteFunc =
            return proc(ctx: RouteContext): RouteResult =
                var c = ctx
                actions
    )
    result

template rf*(c, actions: untyped): untyped =
    var result = (
        proc(ctx: RouteContext): untyped =
            var c = ctx
            actions
    )
    result

# next bind
proc `>=>`*(h1,h2: RouteHandler): RouteHandler =
    return proc(final: RouteFunc): RouteFunc =
        let f2 = h2 final
        let f1 = h1 f2
        rf(ctx) do:  
            f1 ctx
########## routing handlers

# choose func until not abort
proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    rf(ctx) do:
        if funcs.len == 0:
            return RouteResult.none
        
        let tempResponse = ctx.res.clone()
        let tempUrlParams = ctx.req.urlParams.clone()
        let subRouteContext = ctx.subRouteContext
        let res = funcs[0] ctx
        if res != RouteResult.none:
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
            return RouteResult.none

# all
let NOTFOUND*   = filter(rf(_) do: true)

# httpmethod filter
let HEAD*       = filter(rf(ctx) do: ctx.req.reqMethod == HttpHead)
let GET*        = filter(rf(ctx) do: ctx.req.reqMethod == HttpGet)
let POST*       = filter(rf(ctx) do: ctx.req.reqMethod == HttpPost)
let PUT*        = filter(rf(ctx) do: ctx.req.reqMethod == HttpPut)
let DELETE*     = filter(rf(ctx) do: ctx.req.reqMethod == HttpDelete)
let PATCH*      = filter(rf(ctx) do: ctx.req.reqMethod == HttpPatch)
let TRACE*      = filter(rf(ctx) do: ctx.req.reqMethod == HttpTrace)
let OPTIONS*    = filter(rf(ctx) do: ctx.req.reqMethod == HttpOptions)
let CONNECT*    = filter(rf(ctx) do: ctx.req.reqMethod == HttpConnect)

let isNotAuthed* = filter(rf(ctx) do: ctx.user == nil)
let isAuthed* = filter(rf(ctx) do: ctx.user != nil)

# path filter
proc route*(path: string): RouteHandler =
    filter(rf(ctx) do: ctx.req.url.path == ctx.withSubRoute path )

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
            return RouteResult.none
            
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
                return RouteResult.none
                
            let match = opt.get maybe
            let captures = match.captures().toSeq()
            if captures.len() != 2:
                return RouteResult.none
                
            let name = decodeUrl captures[0]
            let typeName = decodeUrl captures[1]
            let value = decodeUrl segment
            
            try:
                case typeName:
                    of "int":
                        discard value.parseInt()
                    of "float":
                        discard value.parseFloat()
                    of "string":
                        discard
                    else: 
                        return RouteResult.none    
                ctx.req.urlParams.setParam(name, value)
            except:
                return RouteResult.none
        return next ctx

proc subRoute*(path: string, handlers: openarray[RouteHandler]): RouteHandler =
    let hs = @handlers
    var h : RouteHandler
    if hs.len() == 0:
        h = handler(c, n) do: n c 
    elif hs.len() == 1:
        h = hs[0]
    else:
        h = choose(hs)

    handler(ctx, next) do:
        if not ctx.req.url.path.startsWith(ctx.withSubRoute path):
            return RouteResult.none
        ctx.updateSubRoute path
        let f = h next
        return f ctx


########## utils handlers 

# cacheable
proc isCached*(ctx: RouteContext, etag: string, maxAge: int): bool = 
    ctx.setHeader("Cache-Control", "max-age=" & $maxage)
    ctx.setHeader("ETag", etag)
    let etagInHeader = ctx.getHeader("If-None-Match")
    return etagInHeader.contains(etag)

proc asCacheable*(getEtag: proc(): string, maxAge: int = 0): RouteHandler =
    handler(ctx, next) do:
        let etag = getEtag()
        if ctx.isCached(etag, maxAge):
            return ctx.resp(Http304, "Not Modified")
        return next ctx

proc resp*(code: HttpCode, content: string): RouteHandler = 
    handler(ctx) do: ctx.resp(code, content)    

proc code*(code: HttpCode): RouteHandler = 
    handler(ctx) do: ctx.code code
    
proc text*(content: string): RouteHandler = 
    handler(ctx) do: ctx.text content

proc html*(content: string): RouteHandler = 
    handler(ctx) do: ctx.html content
    
proc redirect*(location: string, code: HttpCode = Http302): RouteHandler = 
    handler(ctx) do: ctx.redirect(location, code)


# file serve
proc serveDir*(path,localPath: string, maxAge: int = 0): RouteHandler =
    # todo path must be terminate "/"
    var localPath = localPath
    if not localPath.isAbsolute():
        localPath = $(parseUri(getAppDir()) / localPath.replace("./","") )
    handler(ctx) do:
        let routePath = ctx.withSubRoute path
        if not ctx.req.url.path.startsWith(routePath):
            return RouteResult.none
        
        let reqFilePath = 
            decodeUrl ctx.req.url.path[routePath.len()..ctx.req.url.path.len()-1]
        let localFilePath = joinPath(localPath, reqFilePath)
        
        if not localFilePath.startsWith localPath:
            return ctx.code Http403

        if not existsFile localFilePath:
            return RouteResult.none
            
        let fileInfo = os.getFileInfo(localFilePath)
        let hash = md5.getMD5( localFilePath & $(fileInfo.lastWriteTime) )
        if ctx.isCached(hash, maxAge):
            return ctx.code(Http304)
        return ctx.sendFile(localFilePath)
