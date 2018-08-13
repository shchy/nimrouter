import 
    alpaka


let handler = choose(
    route("/") >=> asCacheable(proc():string="etag") >=> text "hello"
)

handler
    .newRouter()
    .useAsyncHttpServer(8080)
    .run()
