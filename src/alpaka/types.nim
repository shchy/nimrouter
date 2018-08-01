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
    Config* = object
        mustBeAuth*         : RouteHandler 
        
    RouteContext*   {.gcsafe.}  = ref object
        req*                : RouteRequest
        res*                : RouteResponse
        subRouteContext*    : string
        user*               : AuthedUser
        config*             : Config

    Router*     = ref object
        handler*        : RouteHandler
        errorHandler*   : ErrorHandler
        middleware*     : RouteHandler
        config*         : Config
        
    
    ErrorHandler*  {.gcsafe.} = proc (ex: ref Exception): RouteHandler {.gcsafe.}

proc newRouter*(handler: RouteHandler): Router =
    Router(
        handler : handler,
        config  : Config()
    )