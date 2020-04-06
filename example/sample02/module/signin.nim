import
  ../../../src/alpaka,
  ../../../src/alpaka/auth/sessionauth,
  ../service/datacontext,
  sequtils
import 
  ../service/models

let signin = handler(ctx) do:
  let id = ctx.req.getFormParam "id"
  let pass = ctx.req.getFormParam "password"
  let _ = ctx.req.getFormParam "isRemember"
  if ctx.signin(id, pass):
    return ctx.redirect("/home/")
  return ctx.redirect("/")

let handlers* = [
  route("/") >=> choose(
    GET >=> isNotAuthed >=> view "views/signin.html",
    GET >=> isAuthed >=> redirect("/home/"),
    POST >=> signin,
  )
]

proc getUser*(id,pass: string): AuthedUser =
  let users = getUsers().filter do (u:User) -> bool: u.id == id and u.password == pass
  if users.len() <= 0:
    return nil
  return AuthedUser(
    id: users[0].id,
    name: users[0].name,
    role: @[],
  )