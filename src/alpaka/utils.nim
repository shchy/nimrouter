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
    handler(ctx, next) do:
        let etag = getEtag()
        if ctx.isCached(etag, maxAge):
            return ctx.resp(Http304, "Not Modified")
        return next ctx

# not next wrapper
proc wrap*(lastFunc: RouteFunc): Routehandler =
    handler(ctx) do:return lastFunc ctx

proc code*(code: HttpCode): RouteHandler = 
    handler(ctx) do: return ctx.code code
    
proc text*(content: string): RouteHandler = 
    handler(ctx) do: return ctx.text content

proc html*(content: string): RouteHandler = 
    handler(ctx) do: return ctx.html content
    
proc redirect*(location: string, code: HttpCode = Http302): RouteHandler = 
    handler(ctx) do: return ctx.redirect(location, code)
    
let mustBeAuth* = handler(ctx, next) do:
    return (ctx.config.mustBeAuth next) ctx
