import 
    alpaka,
    alpaka/auth/sessionauth,
    module/signin,
    module/home


let handler = choose(
    subRoute("/",           signin.handlers),
    subRoute("/home/",      home.handlers),
    serveDir("/static/", "./assets/", 60 * 60 * 24 * 7)
)

handler
    .newRouter()
    .useSessionAuth(getUser, "/", "authCookie", "hash", 60 * 30)
    .useAsyncHttpServer(8080)
    .run()
