import 
    asynchttpserver,
    asyncdispatch,
    htmlgen,
    httpcore,
    os,
    tables,
    alpaka
import
    modules/index

proc main() =
    var r = Router(
        handler         : choose(
            subRoute("/", index.handlers),
            GET >=> serveDir("/static/", "./static/", 60 * 60 * 24 * 7)
        )
    )
    # bind router to asynchttpserver
    proc cb(req:Request) {.async.} =
        await r.routing(req)

    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()