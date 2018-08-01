import 
    alpaka,
    indexview,
    emerald,
    strutils,
    base64

let home = handler(ctx) do:
    return ctx.html homeView(ctx.user.name)

let handlers* = [
    GET     >=> 
        # route("/signin")        >=> html signinView(),
        route("/")              >=> mustBeAuth  >=> home,
    # POST    >=>
        # route("/signin")        >=> signin
]
