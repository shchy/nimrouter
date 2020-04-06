import
  httpcore,
  strutils,
  base64,
  sequtils,
  sugar
import 
  ../core/context,
  ../core/handlers,
  ../router/router

type
  GetUser*  = proc(id,pass:string): AuthedUser  
  BasicAuth*  = ref object of Middleware
    getUser   : GetUser
    realm     : string

# Basic auth
proc before(getUser: GetUser): RouteHandler =
  handler(ctx, next) do:
    let auth = ctx.getHeader("Authorization")
    if auth.isNilOrWhitespace:
      return next ctx
  
    let splited = auth.split(" ")
    if splited.len() != 2:
      return next ctx
      
    let authMethod = toLowerAscii splited[0]
    if authMethod != "basic":
      return next ctx
      
    let idWithPass = (base64.decode splited[1]).split(":")
    if idWithPass.len() != 2:
      return next ctx
      
    let id = idWithPass[0]
    let password = idWithPass[1]
    let user = getUser(id, password)
    if user != nil:
      ctx.user = user
    return next ctx


let mustBeAuth* = 
  handler(ctx, next) do:
    let basicAuth = getMiddleware[BasicAuth](ctx)
    if basicAuth == nil :
      return RouteResult.none
    
    if ctx.user == nil:
      ctx.setHeader("WWW-Authenticate", "Basic realm=" & basicAuth.realm)
      return ctx.code Http401
    return next ctx
      
proc useBasicAuth*(router: Router, getUser: GetUser, realm: string): Router =
  let middleware = BasicAuth(
    before    : before(getUser),
    after     : (handler(c,n) do: n c),
    getUser   : getUser,
    realm     : realm
  )
  router.addMiddleware(middleware)
  return router

