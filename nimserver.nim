import 
    asynchttpserver, 
    asyncdispatch,
    htmlgen
import nimserverpkg/router

proc main() =

    proc index(req: Request) : Future[void] =
        req.respond(Http200, h1 "Hello")

    proc notfound(r:Request) : Future[void] =
        r.respond(Http404, "404")

    var indexRoute = get("/", index)
    var testRoute = get("/{i}", index)
    var r = newRouter(notfound, indexRoute, testRoute)
    
    
    proc cb(req:Request){.async.} =
        await r.routing(req)
    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()