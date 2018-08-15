import 
    alpaka,
    alpaka/auth/sessionauth,
    sequtils,
    module/signin,
    module/home,
    service/datacontext


let handler = choose(
    subRoute("/", signin.handlers),
    subRoute("/home/", home.handlers),
    serveDir("/static/", "./assets/", 60 * 60 * 24 * 7)
)

proc getUser(id,pass: string): AuthedUser =
    let users = getUsers().filter do (u:User) -> bool: u.id == id and u.password == pass
    if users.len() <= 0:
        return nil
    return AuthedUser(
        id: users[0].id,
        name: users[0].name,
        role: @[],
    )
        

handler
    .newRouter()
    .useSessionAuth(getUser, "/", "authCookie", "hash", 60 * 30)
    .useAsyncHttpServer(8080)
    .run()
