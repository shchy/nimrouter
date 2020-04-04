import 
    unittest,
    strutils,
    base64,
    testcommon,
    ../src/alpaka,
    ../src/alpaka/auth/basicauth


suite "test basicauth":
    let handler = choose(
        GET >=> route("/") >=> text "hello",
        GET >=> route("/auth/") >=> mustBeAuth >=> (handler(ctx) do: ctx.text "hello " & ctx.user.name)
    )
    let getUser = proc(id,pass: string): AuthedUser =
        if id != "tester" or pass != "password":
            return nil
        return AuthedUser(
            id: id,
            name: id,
            role: @["normal"]
        )
    let realm = "must be signin"
    let idWithPass = base64.encode "tester:password"
    let router = newRouter(handler).useBasicAuth(getUser, realm)
    test "basicauth":
        var context = router.routingTest(HttpGet, "/")
        check(context.res.body == "hello")
        check(context.res.code == Http200)
        check(context.res.headers["content-type"] == "text/plain")
        check(isNilOrWhitespace context.res.contentFilePath)

        context = router.routingTest(HttpGet, "/auth/")
        check(context.res.body == "")
        check(context.res.code == Http401)
        check(context.res.headers["WWW-Authenticate"] == "Basic realm=" & realm)
        check(isNilOrWhitespace context.res.contentFilePath)
        
        context = router.routingTest(HttpGet, "/auth/", "", (key:"Authorization", value:"basic " & idWithPass))
        check(context.res.body == "hello tester")
        check(context.res.code == Http200)
        check(isNilOrWhitespace context.res.contentFilePath)
