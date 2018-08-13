import 
    alpaka,
    module/signin


let handler = choose(
    subRoute("/", signin.handlers)
    # route("/") >=> asCacheable(proc():string="etag") >=> text "hello"
)

handler
    .newRouter()
    .useAsyncHttpServer(8080)
    .run()
