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
        mustBeAuth*     : RouteHandler
    Router*     = ref object
        handler*        : RouteHandler
        errorHandler*   : ErrorHandler
        middleware*     : RouteHandler
        mustBeAuth*     : RouteHandler
        
    
    ErrorHandler*  {.gcsafe.} = proc (ex: ref Exception): RouteHandler {.gcsafe.}
        