import 
    httpcore,
    tables,
    sequtils,
    strutils
import 
    core

# cacheable
proc isCached*(ctx: RouteContext, etag: string, maxAge: int): bool = 
    ctx.setHeader("Cache-Control", "max-age="& $maxage)
    ctx.setHeader("ETag", etag)
    let etagInHeader = ctx.getHeader("If-None-Match")
    return etagInHeader.contains(etag)

proc asCacheable*(getEtag: proc(): string, maxAge: int): RouteHandler =
    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            let etag = getEtag()
            if ctx.isCached(etag, maxAge):
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

proc html*(content: string): RouteHandler =
    return wrap(proc(ctx: RouteContext): RouteResult = ctx.html content)
    
proc redirect*(location: string, code: HttpCode = Http302): RouteHandler =
    return wrap(proc(ctx: RouteContext): RouteResult = ctx.redirect(location, code))


