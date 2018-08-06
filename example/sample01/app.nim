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
    proc debugAuth(id,pass:string) : AuthedUser =
        let isOK = id == "testa" and pass == "test"
        if not isOK:
            return nil
        var user = AuthedUser(
            id  : id,
            name: id,
            role: @[]
        )
        return user

    var r = Router(
        handler         : choose(
            subRoute("/", index.handlers),
            GET >=> serveDir("/static/", "./static/", 60 * 60 * 24 * 7)
        )
    ).useSessionAuth(debugAuth, "/", "cookieName", "asdfghjk", 60 * 5, "/", false, true)
    #.useBasicAuth(debugAuth, "must be signin")
    
    # bind router to asynchttpserver
    proc cb(req:Request) {.async.} =
        await r.routing(req)

    let server = newAsyncHttpServer(true, true)
    waitfor server.serve(Port(8080), cb)

main()