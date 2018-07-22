import asynchttpserver, asyncdispatch
import nimserverpkg/router

proc main() =
    var server = newAsyncHttpServer()

    proc index(req: Request) : Future[void] =
        req.respond(Http200, "Hello")

    proc notfound(r:Request) : Future[void] =
        r.respond(Http404, "404")

    var indexRoute = 
        Route(
            path: "/",
            httpMethod: HttpGet,
            handler: index
        )

    var r = newRouter(notfound, indexRoute)

    proc cb(req:Request){.async.} =
        await r.routing(req)

    waitfor server.serve(Port(8080), cb)

main()