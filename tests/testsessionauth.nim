import 
  unittest,
  strutils,
  sequtils,
  testcommon,
  ../src/alpaka,
  ../src/alpaka/auth/sessionauth


suite "test sessionauth":
  let handler = choose(
    GET >=> route("/") >=> text "hello",
    GET >=> route("/auth/") >=> mustBeAuth >=> (handler(ctx) do: ctx.text "hello " & ctx.user.name),
    GET >=> route("/signin") >=> (handler(ctx) do: 
      if ctx.signin(ctx.req.getQueryParam "id",ctx.req.getQueryParam "pass"):
        return ctx.redirect("/auth/", Http303)
      return ctx.code Http401      
      ),
  )
  let getUser = proc(id,pass: string): AuthedUser =
    if id != "tester" or pass != "password":
      return nil
    return AuthedUser(
      id: id,
      name: id,
      role: @["normal"]
    )
  let router = 
    newRouter(handler)
    .useSessionAuth(getUser, "/", "cookieName", "hashKey"
    , 1000, "/", false, true)
  test "sessionauth":
    var context = router.routingTest(HttpGet, "/")
    check(context.res.body == "hello")
    check(context.res.code == Http200)
    check(context.res.headers["content-type"] == "text/plain")
    check(isNilOrWhitespace context.res.contentFilePath)

    context = router.routingTest(HttpGet, "/auth/")
    check(context.res.body == "")
    check(context.res.code == Http302)
    check(context.res.headers["Location"] == "/")
    check(isNilOrWhitespace context.res.contentFilePath)
    
    context = router.routingTest(HttpGet, "/signin?id=aa&pass=bb")
    check(context.res.body == "")
    check(context.res.code == Http401)
    check(isNilOrWhitespace context.res.contentFilePath)


    context = router.routingTest(HttpGet, "/signin?id=tester&pass=password")
    check(context.res.body == "")
    check(context.res.code == Http303)
    check(context.res.headers["Location"] == "/auth/")
    check(isNilOrWhitespace context.res.contentFilePath)

    let authkey = 
      sequtils.filter(seq[string](context.res.headers["set-cookie"]),
      proc (s:string): bool = s.contains("cookieName"))[0]
      .split(";")[0].split("=")[1]
    context = router.routingTest(HttpGet, "/auth/", "", (key:"cookie", value: "cookieName=" & authkey))
    check(context.res.body == "hello tester")
    check(context.res.code == Http200)
    check(isNilOrWhitespace context.res.contentFilePath)
    
