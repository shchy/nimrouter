import 
    asynchttpserver, 
    asyncdispatch,
    htmlgen
import nimserverpkg/router

proc main() =

    proc index(f: RouteFunc): RouteFunc =
        return proc(req: Request) : RouteResult =
            return RouteResult(request:req.respond(Http200, h1 "Hello"))

    proc notfound(f: RouteFunc): RouteFunc =
        return proc(r:Request) : RouteResult =
            return RouteResult(request:r.respond(Http404, "404"))

    var indexRoute = get >=> index
    
    var handler = choose(@[indexRoute])
    # var testRoute = get("/{i}", index)
    var r = newRouter(handler, notfound)
    
    proc cb(req:Request) {.async.} =
        await r.routing(req)
    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()
