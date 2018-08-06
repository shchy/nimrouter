import 
    alpaka,
    indexview,
    strutils,
    base64

let home = handler(ctx) do:
    return ctx.html homeView(ctx.user.name)

let login = handler(ctx) do:
    let id = ctx.req.getUrlParam "id"
    let pass = ctx.req.getUrlParam "pass"
    let isOK = ctx.signin(id, pass)
    return ctx.text($isOK)

let logout = handler(ctx) do:
    ctx.signout()
    return ctx.text "signout"


let handlers* = [
    GET     >=> 
        routep("/signin/{id: string}/{pass: string}")   >=> login,
        route("/signout/")                              >=> logout,
        route("/home/")                                 >=> mustBeAuth  >=> home,
        route("/")                                      >=> (handler(ctx) do: return ctx.text "hello"),
    # POST    >=>
        # route("/signin")        >=> signin
]
