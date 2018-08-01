import
    httpcore,
    strutils,
    base64
import 
    types,
    core

# Basic auth
proc basicAuth(getUser: GetUser): RouteHandler =
    handler(ctx, next) do:
        let auth = ctx.getHeader("Authorization")
        if auth == nil:
            return next ctx
    
        let splited = auth.split(" ")
        if splited.len() != 2:
            return next ctx
            
        let authMethod = toLowerAscii splited[0]
        if authMethod != "basic":
            return next ctx
            
        let idWithPass = (base64.decode splited[1]).split(":")
        let id = idWithPass[0]
        let password = idWithPass[1]
        let user = getUser(id, password)
        if user != nil:
            ctx.user = user
        return next ctx


proc mustBeAuth(getUser: GetUser, realm: string): RouteHandler =
    handler(ctx, next) do:
        if ctx.user == nil:
            ctx.setHeader("WWW-Authenticate", "Basic realm=" & realm)
            return ctx.code Http401
        return next ctx
            
proc useBasicAuth*(router: Router, getUser: GetUser, realm: string): Router =
    var before = router.middleware
    if before == nil:
        before = through
    router.middleware = before >=> basicAuth(getUser)
    router.config.mustBeAuth = mustBeAuth(getUser, realm)
    return router

