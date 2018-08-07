# depend on asynchttpserver is only this  
import 
    httpcore,
    asyncdispatch,
    asynchttpServer,
    tables,
    uri,
    os,
    asyncnet,
    streams,
    sequtils
import
    ../core/context

type 
    Router*        = ref object of RootObj
        handler*        : RouteHandler
        errorHandler*   : ErrorHandler
        middlewares*    : seq[Middleware]    

method sendFile*(this: Router, req: Request, code: HttpCode, headers: HttpHeaders, filePath: string): Future[void] =
    discard

method bindContextToResponse*(this: Router, req: Request, ctx: RouteContext): Future[void] =
    discard



proc newRouter*(handler: RouteHandler, errorHandler: ErrorHandler = nil): Router =
    Router(
        handler     : handler,
        errorHandler: errorHandler,
        middlewares : @[]
    )

