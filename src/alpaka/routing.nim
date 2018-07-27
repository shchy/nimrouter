import
    httpcore,
    strutils,
    sequtils,
    parseutils,
    tables,
    nre, options as opt

import 
    core

### filters

# filter by context
proc filter*(isMatch:proc(ctx:RouteContext): bool): RouteHandler =
    return proc(next: RouteFunc): RouteFunc = 
        return proc(ctx:RouteContext): RouteResult =
            if isMatch ctx:
                return next ctx
            else:
                return abort


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
                        else: 
                            discard    
                    ctx.urlParams.add(name, segment)
                except:
                    return abort
            
            return next ctx


