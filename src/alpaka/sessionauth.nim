import
    httpcore,
    strutils,
    tables,
    md5
import 
    types,
    core

const cookieName = "AuthCookie"
var debug : tuple[hashKey: string, getUser: GetUser]

var cache: Table[string, tuple[id: string,pass: string]] = 
    initTable[string,tuple[id: string,pass: string]]()

# Basic auth
proc basicAuth(getUser: GetUser): RouteHandler =
    handler(ctx, next) do:
        let hash = ctx.getCookie(cookieName)
        
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
    ctx.setCookie(cookieName, hash, 60 * 5) 
    cache[hash] = (id: id, pass: pass)
    return true

proc signout*(ctx: RouteContext): void = 
    if ctx.user == nil:
        return
    let hash = md5.getMD5(debug.hashKey & ctx.user.id)
    if cache.haskey hash:
        cache.del hash
    ctx.user = nil
            
proc useSessionAuth*(router: Router, getUser: GetUser, redirectPath, hashKey: string): Router =
    debug = (hashKey: hashKey, getUser: getUser)
    var before = router.middleware
    if before == nil:
        before = through
    router.middleware = before >=> basicAuth(getUser)
    router.config.mustBeAuth = mustBeAuth(getUser, redirectPath)
    
    return router

