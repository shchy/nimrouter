import 
    httpcore,
    tables,
    sequtils,
    strutils
import 
    core

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

proc redirect*(location: string, code: HttpCode = Http302): RouteHandler =
    return wrap(proc(ctx: RouteContext): RouteResult = ctx.redirect(location, code))


