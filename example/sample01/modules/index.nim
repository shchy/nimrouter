import 
    alpaka,
    indexview,
    emerald


proc login(next: RouteFunc): RouteFunc = 
    return proc(ctx: RouteContext): RouteResult = 
        return ctx.html view()


let handlers* = [
    GET >=> 
        route("/")  >=> login
]
