import 
    alpaka,
    indexview,
    emerald,
    strutils,
    base64

proc home(next: RouteFunc): RouteFunc =
    return proc(ctx: RouteContext): RouteResult =
        return ctx.html homeView(ctx.user.name)

let handlers* = [
    GET     >=> 
        # route("/signin")        >=> html signinView(),
        route("/")              >=> mustBeAuth  >=> home,
    # POST    >=>
        # route("/signin")        >=> signin
]
