import
    httpcore,
    strutils,
    sequtils,
    parseutils,
    tables,
    nre, options as opt

import 
    core

# varargs to seq
proc `@`[T](xs:openArray[T]): seq[T] = 
    var s: seq[T] = @[]
    for x in xs:
        s.add x
    return s

# backup responce
proc backup(res: RouteResponse): RouteResponse =
    let code = res.code
    let body = res.body
    let headers = newHttpHeaders()

    for key in res.headers.table.keys:
        for val in res.headers.table[key]:
            headers.add(key, val)
    return RouteResponse(
        code: code,
        body: body,
        headers: headers
    )

# 
let abort* = RouteResult.none

# choose func until not abort
proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    return proc(ctx: RouteContext): RouteResult =
        if funcs.len == 0:
            return abort
        
        let tempResponse = ctx.response.backup()
        let tempUrlParams = ctx.request.urlParams.clone()
        let res = funcs[0] ctx
        if res != abort:
            return res
        
        # reset response
        ctx.response = tempResponse
        ctx.request.urlParams = tempUrlParams
        
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
let notfound*    = filter(proc(ctx: RouteContext): bool = true)

# httpmethod filter
let head*   = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpHead)
let get*    = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpGet)
let post*   = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpPost)
let put*    = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpPut)
let delete* = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpDelete)
let patch*  = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpPatch)
let trace*  = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpTrace)
let options*   = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpOptions)
let connect*   = filter(proc(ctx:RouteContext):bool = ctx.request.reqMethod == HttpConnect)

# path filter
proc route*(path: string): RouteHandler =
    return filter(proc(ctx: RouteContext): bool = ctx.request.url.path == path )

const urlParamRegex = r"{\s?(\w+?)\s?:\s?(int|string|float)\s?}"
# path filter with url parameter
# ex.
#   /user/{ id : string }
#   /blog/{year : int}/{ month : int }/{ day : int }/{ id : int}
proc routep*(path: string): RouteHandler =
    let expectedSegments = path.split("/")

    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            let segemnts = ctx.request.url.path.split("/")
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
                    ctx.request.urlParams.setParam(name, segment)
                except:
                    return abort
            
            return next ctx


