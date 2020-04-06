import 
  ../../../src/alpaka,
  ../../../src/alpaka/auth/sessionauth

let home = handler(ctx) do:
  ctx.text ctx.user.name

let login = handler(ctx) do:
  let id = ctx.req.getUrlParam "id"
  let pass = ctx.req.getUrlParam "pass"
  let isOK = ctx.signin(id, pass)
  ctx.text($isOK)

let logout = handler(ctx) do:
  ctx.signout()
  ctx.text "signout"


let handlers* = [
  GET   >=> 
    routep("/signin/{id: string}/{pass: string}")   >=> login,
    route("/signout/")                >=> logout,
    route("/home/")                 >=> mustBeAuth  >=> home,
    route("/")                    >=> (handler(ctx) do: ctx.text "hello"),
  # POST  >=>
    # route("/signin")    >=> signin
]
