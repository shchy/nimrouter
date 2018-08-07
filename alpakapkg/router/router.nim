# depend on asynchttpserver is only this  
import 
    httpcore,
    sequtils
import
    ../core/context

type 
    Router*        = ref object of RootObj
        handler*        : RouteHandler
        errorHandler*   : ErrorHandler
        middlewares*    : seq[Middleware] 
        

proc newRouter*(handler: RouteHandler, errorHandler: ErrorHandler = nil): Router =
    Router(
        handler     : handler,
        errorHandler: errorHandler,
        middlewares : @[]
    )
        
proc defaultErrorHandler(ex: ref Exception): RouteHandler =
    handler(ctx) do: ctx.resp(Http500, "Internal Server Error")

proc final*(ctx: RouteContext): RouteResult {.procvar.} =
    RouteResult.find
    
proc routing*(router: Router, ctx: RouteContext): RouteContext =
    var errorHandler = router.errorHandler
    if errorHandler == nil:
        errorHandler = defaultErrorHandler
    
    let through : RouteHandler = handler(c,n) do:return n c


    try:
        let before = filter(router.middlewares.map do (m:Middleware) -> RouteHandler: m.before
                        , proc (h: RouteHandler): bool = h != nil)
                        .foldl(a >=> b, through)
        let after = filter(router.middlewares.map do (m:Middleware) -> RouteHandler: m.after
                        , proc (h: RouteHandler): bool = h != nil)
                        .foldl(a >=> b, through)
        
        let handler = before >=> router.handler

        let res = (handler final) ctx

        if res == RouteResult.none:
            ctx.res.clear()
            discard ctx.resp(Http404, "404 NotFound")
            return ctx
        
        discard (after final) ctx
        
        return ctx
    except:
        let ex = getCurrentException()
        let msg = getCurrentExceptionMsg()
        echo "Exception" & repr(ex) & " message:" & msg
        ctx.res.clear()

        if errorHandler == nil:
            discard ctx.resp(Http500, "Internal Server Error")
            return ctx
        let handler = errorHandler ex
        let res = (handler final) ctx
        if res == RouteResult.none:
            discard ctx.resp(Http500, "Internal Server Error")
            return ctx
            
        return ctx


    



