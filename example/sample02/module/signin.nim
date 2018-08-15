import
    alpaka,
    alpaka/auth/sessionauth,
    views/signinview

let signin = handler(ctx) do:
    let id = ctx.req.getFormParam "id"
    let pass = ctx.req.getFormParam "password"
    let isRemember = ctx.req.getFormParam "isRemember"
    if ctx.signin(id, pass):
        return ctx.redirect("/home/")
    return ctx.redirect("/")


let handlers* = [
    route("/") >=> choose(
        GET >=> isNotAuthed >=> html view(),
        GET >=> isAuthed >=> redirect("/home/"),
        POST >=> signin,
    )
]