import
    httpcore,
    strutils,
    tables,
    md5,
    sequtils
import 
    ../core/context,
    ../core/handlers,
    ../router/router

type
    GetUser*      = proc(id,pass:string): AuthedUser    
    SessionAuth*  = ref object of Middleware
        getUser     : GetUser
        cache       : Table[string, tuple[id: string,pass: string]]  
        cookieName  : string
        redirectPath: string
        hashKey     : string 
        maxage      : int 
        cookiepath  : string 
        isSecure    : bool 
        isHttpOnly  : bool

proc before(getUser: GetUser): RouteHandler =
    handler(ctx, next) do:
        let sessionAuth = getMiddleware[SessionAuth](ctx)
        if sessionAuth == nil :
            return next ctx

        let hash = ctx.getCookie(sessionAuth.cookieName)
        
        if hash.isNilOrWhitespace:
            return next ctx
        if not sessionAuth.cache.hasKey hash:
            return next ctx
        
        let loginCache = sessionAuth.cache[hash]
            
        let user = getUser(loginCache.id, loginCache.pass)
        if user != nil:
            ctx.user = user
        return next ctx

let mustBeAuth* =
    handler(ctx, next) do:
        let sessionAuth = getMiddleware[SessionAuth](ctx)
        if sessionAuth == nil :
            return RouteResult.none
        if ctx.user == nil:
            return ctx.redirect sessionAuth.redirectPath
        return next ctx

proc signin*(ctx: RouteContext, id, pass: string): bool =
    let sessionAuth = getMiddleware[SessionAuth](ctx)
    if sessionAuth == nil :
        return false

    let user = sessionAuth.getUser(id, pass)
    if user == nil:
        return false

    ctx.user = user
    let hash = md5.getMD5(sessionAuth.hashKey & id)
    ctx.setCookie(sessionAuth.cookieName, hash
                , sessionAuth.maxage
                , sessionAuth.isSecure, sessionAuth.isHttpOnly
                , sessionAuth.cookiepath) 
    sessionAuth.cache[hash] = (id: id, pass: pass)
    return true

proc signout*(ctx: RouteContext): void = 
    if ctx.user == nil:
        return
    let sessionAuth = getMiddleware[SessionAuth](ctx)
    if sessionAuth == nil :
        return 
    let hash = md5.getMD5(sessionAuth.hashKey & ctx.user.id)
    if sessionAuth.cache.haskey hash:
        sessionAuth.cache.del hash
    ctx.user = nil
            
proc useSessionAuth*(router: Router, getUser: GetUser
                    , redirectPath, cookieName, hashKey: string
                    , maxage: int = 60 * 60 * 7, cookiepath: string = "/"
                    , isSecure: bool = false, isHttpOnly: bool = true): Router =
    let middleware = SessionAuth(
        before      : before(getUser),
        after       : (handler(c,n) do : n c),
        cookieName  : cookieName,
        redirectPath: redirectPath,
        hashKey     : hashKey, 
        getUser     : getUser, 
        maxage      : maxage, 
        cookiepath  : cookiepath, 
        isSecure    : isSecure, 
        isHttpOnly  : isHttpOnly,
        cache       : initTable[string,tuple[id: string,pass: string]]()
        )
    router.addMiddleware(middleware)
    return router

