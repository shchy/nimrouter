import
    httpcore,
    strutils,
    base64
import 
    types,
    core


# Basic auth
proc getUserByBasicAuth(ctx: RouteContext, getUser: GetUser): AuthedUser = 
    let auth = ctx.getHeader("Authorization")
    if auth == nil:
        return nil

    let splited = auth.split(" ")
    if splited.len() != 2:
        return nil
        
    let authMethod = toLowerAscii splited[0]
    if authMethod != "basic":
        return nil
        
    let idWithPass = (base64.decode splited[1]).split(":")
    let id = idWithPass[0]
    let password = idWithPass[1]
    let user = getUser(id, password)
    return user

proc basicAuth(getUser: GetUser): RouteHandler =
    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            let user = ctx.getUserByBasicAuth(getUser)
            if user == nil:
                return next ctx
            ctx.user = user
            return next ctx

proc mustBeAuth(getUser: GetUser, realm: string): RouteHandler =
    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            if ctx.user == nil:
                ctx.setHeader("WWW-Authenticate", "Basic realm=" & realm)
                return ctx.code Http401
            return next ctx
            
proc useBasicAuth*(router: Router, getUser: GetUser, realm: string): Router =
    var before = router.middleware
    if before == nil:
        before = through
    router.middleware = before >=> basicAuth(getUser)
    router.mustBeAuth = mustBeAuth(getUser, realm)
    return router

