import
    request,
    response
    
type
    RouteResult*    = enum 
        none, find 
    RouteFunc*                  = proc (ctx:RouteContext): RouteResult
    RouteHandler*   {.gcsafe.}  = proc (f:RouteFunc): RouteFunc
    AuthedUser* = ref object
        id*     : string
        name*   : string
        role*   : seq[string]  
    GetUser*                    = proc(id,pass:string): AuthedUser    
    RouteContext*   {.gcsafe.}  = ref object
        req*                : RouteRequest
        res*                : RouteResponse
        subRouteContext*    : string
        user*               : AuthedUser
        middlewares*        : seq[Middleware]

    Router*     = ref object
        handler*        : RouteHandler
        errorHandler*   : ErrorHandler
        middlewares*    : seq[Middleware]    
    ErrorHandler*  {.gcsafe.} = proc (ex: ref Exception): RouteHandler {.gcsafe.}

    Middleware*     = ref object of RootObj
        before*     : RouteHandler
        after*      : RouteHandler


proc newRouter*(handler: RouteHandler, errorHandler: ErrorHandler = nil): Router =
    Router(
        handler     : handler,
        errorHandler: errorHandler,
        middlewares : @[]
    )