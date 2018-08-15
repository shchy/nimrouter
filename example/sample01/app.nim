import 
    asynchttpserver,
    asyncdispatch,
    htmlgen,
    httpcore,
    os,
    tables,
    alpaka,
    alpaka/auth/sessionauth
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

    var r = newRouter(
        choose(
            subRoute("/", index.handlers),
            GET >=> serveDir("/static/", "./static/", 60 * 60 * 24 * 7)
        )
    ).useSessionAuth(debugAuth, "/", "cookieName", "asdfghjk", 60 * 5, "/", false, true)
    .useAsyncHttpServer(8080)
    #.useBasicAuth(debugAuth, "must be signin")
    
    r.run()

main()