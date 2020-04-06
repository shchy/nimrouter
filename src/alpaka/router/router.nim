import 
  httpcore,
  sequtils,
  sugar
import
  ../core/context,
  ../core/handlers

type 
  Router* = ref object of RootObj
    handler     : RouteHandler
    errorHandler  : ErrorHandler
    middlewares   : seq[Middleware] 
    buildedFunc   : RouteFunc
    buildedAfter  : RouteFunc
    
proc newRouter*(handler: RouteHandler, errorHandler: ErrorHandler = nil): Router =
  Router(
    handler   : handler,
    errorHandler: errorHandler,
    middlewares : @[]
  )

proc addMiddleware*(router: Router, middleware: Middleware) =
  router.middlewares.add(middleware)

proc build*(router: Router): void =
  if router.buildedFunc != nil:
    return

  var errorHandler = router.errorHandler
  if errorHandler == nil:
    errorHandler = 
      proc (ex: ref Exception): RouteHandler =
        handler(ctx) do: ctx.resp(Http500, "Internal Server Error")
  
  let through: RouteHandler = handler(c, n) do: return n c
    
  let before = router.middlewares.map(m => m.before)
    .filter(h => h != nil)
    .foldl(a >=> b, through)
  let after = router.middlewares.map(m => m.after)
    .filter(h => h != nil)
    .foldl(a >=> b, through)

  let handler = before >=> router.handler
  let final = ((_: RouteContext) => RouteResult.find)

  router.buildedFunc = (handler final)
  router.buildedAfter = (after final)

proc routing*(router: Router, ctx: RouteContext): RouteContext {.gcsafe.} =
  
  router.build()

  ctx.middlewares = router.middlewares

  let final = ((_: RouteContext) => RouteResult.find)

  try:
    
    let res = router.buildedFunc ctx

    if res == RouteResult.none:
      ctx.res.clear()
      discard ctx.resp(Http404, "404 NotFound")
      return ctx
    
    discard router.buildedAfter ctx
    
    return ctx
  except Exception as ex:
    let msg = ex.msg
    echo "Exception" & repr(ex) & " message:" & msg
    ctx.res.clear()

    if router.errorHandler == nil:
      discard ctx.resp(Http500, "Internal Server Error")
      return ctx
    let handler = router.errorHandler ex
    let res = (handler final) ctx
    if res == RouteResult.none:
      discard ctx.resp(Http500, "Internal Server Error")
      return ctx
      
    return ctx


proc run*(router: Router): void =
  let runners = router.middlewares.map(m => m.run)
    .filter(h => h != nil)
  if runners.len() < 0:
    return
  let runner = runners[0]
  runner()
  



