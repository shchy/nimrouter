import
    httpcore,
    strutils,
    tables,
    md5
import 
    types,
    core

var debug : tuple[
    cookieName: string,
    hashKey: string, 
    getUser: GetUser, 
    maxage: int, 
    path: string, 
    isSecure: bool, 
    isHttpOnly: bool
    ]

# todo add timeout
var cache: Table[string, tuple[id: string,pass: string]] = 
    initTable[string,tuple[id: string,pass: string]]()

# Basic auth
proc before(getUser: GetUser): RouteHandler =
    handler(ctx, next) do:
        let hash = ctx.getCookie(debug.cookieName)
        
        if hash.isNilOrWhitespace:
            return next ctx
        if not cache.hasKey hash:
            return next ctx
        
        let loginCache = cache[hash]
            
        let user = getUser(loginCache.id, loginCache.pass)
        if user != nil:
            ctx.user = user
        return next ctx

proc mustBeAuth(getUser: GetUser, redirectPath: string): RouteHandler =
    handler(ctx, next) do:
        if ctx.user == nil:
            return ctx.redirect redirectPath
        return next ctx

proc signin*(ctx: RouteContext, id, pass: string): bool =
    let user = debug.getUser(id, pass)
    if user == nil:
        return false

    ctx.user = user
    let hash = md5.getMD5(debug.hashKey & id)
    ctx.setCookie(debug.cookieName, hash, debug.maxage, debug.path, debug.isSecure, debug.isHttpOnly) 
    cache[hash] = (id: id, pass: pass)
    return true

proc signout*(ctx: RouteContext): void = 
    if ctx.user == nil:
        return
    let hash = md5.getMD5(debug.hashKey & ctx.user.id)
    if cache.haskey hash:
        cache.del hash
    ctx.user = nil
            
proc useSessionAuth*(router: Router, getUser: GetUser, redirectPath
                    , cookieName, hashKey: string
                    , maxage: int, path: string
                    , isSecure, isHttpOnly: bool): Router =
    debug = (
        cookieName: cookieName,
        hashKey: hashKey, 
        getUser: getUser, 
        maxage: maxage, 
        path: path, 
        isSecure: isSecure, 
        isHttpOnly: isHttpOnly
        )
    var origin = router.middleware
    if origin == nil:
        origin = through
    router.middleware = origin >=> before(getUser)
    router.config.mustBeAuth = mustBeAuth(getUser, redirectPath)
    
    return router

