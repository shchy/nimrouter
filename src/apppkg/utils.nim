import 
    httpcore,
    tables,
    sequtils,
    strutils
import 
    core

### context utils
proc resp*(ctx: RouteContext, code: HttpCode, content: string): RouteResult =
    ctx.response.code = code
    ctx.response.body = content
    return RouteResult(context: ctx)

proc code*(ctx: RouteContext, code: HttpCode): RouteResult =
    ctx.response.code = code
    return RouteResult(context: ctx)
    
proc text*(ctx: RouteContext, content: string): RouteResult =
    return ctx.resp(Http200, content)

proc setHeader*(ctx: RouteContext, key, val: string): void =
    ctx.response.headers.add(key, val)

proc getHeader*(ctx: RouteContext, key: string): string =
    return ctx.request.headers.getOrDefault(key)

proc redirect*(ctx: RouteContext, path: string): RouteResult =
    ctx.setHeader("Location", path)
    return ctx.code Http302

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
let abort*:RouteResult = nil

# choose func until not abort
proc chooseFuncs(funcs:seq[RouteFunc]): RouteFunc = 
    return proc(ctx: RouteContext): RouteResult =
        let temp = ctx.response.backup()
        if funcs.len == 0:
            return nil
        else:
            let res = funcs[0] ctx
            if res != nil:
                return res
            else:
                # reset response
                ctx.response = temp
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

# filter by context
proc filter*(isMatch:proc(ctx:RouteContext): bool): RouteHandler =
    return proc(next: RouteFunc): RouteFunc = 
        return proc(ctx:RouteContext): RouteResult =
            if isMatch ctx:
                return next ctx
            else:
                return abort

# next bind
proc `>=>`*(h1,h2: RouteHandler): RouteHandler =
    return proc(final: RouteFunc): RouteFunc =
        let f2 = h2 final
        let f1 = h1 f2
        return proc(ctx: RouteContext): RouteResult = 
            return f1 ctx

# cacheable
proc asCacheable*(getEtag: proc(): string, maxAge: int): RouteHandler =
    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            let etag = getEtag()
            ctx.setHeader("Etag", etag)
            ctx.setHeader("Cache-Control", "max-age=" & $maxage)
            let etagInHead = ctx.getHeader("If-None-Match")
            if etagInHead.contains(etag):
                return ctx.resp(Http304, "Not Modified")
            return next ctx

# not next wrapper
proc wrap*(lastFunc: RouteFunc): Routehandler =
    return proc(_: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            return lastFunc ctx


proc code*(code: HttpCode): RouteHandler =
    return wrap(proc(ctx: RouteContext): RouteResult = ctx.code code)
    
proc text*(content: string): RouteHandler =
    return wrap(proc(ctx: RouteContext): RouteResult = ctx.text content)

### filters

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

proc routef*[T](path: string, argsHandler: proc(args: T, f: RouteFunc): RouteFunc): RouteHandler =
    return proc(next: RouteFunc): RouteFunc =
        return argsHandler(1, next)



