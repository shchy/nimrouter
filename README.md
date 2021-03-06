# Http Request Router

giraffe(F#) copy


## How to use

```nim
let handler = choose(
  GET >=> choose(
    route("/")    >=> text "hello world",
    route("/ping/") >=> html "pong",
  ),  
)

handler
  .newRouter()
  .useAsyncHttpServer(8080)
  .run()


```

## urlParameter

```nim
let urlParamHandler = handler(ctx) do:
  let id = ctx.req.getUrlParam "userid"
  let year = ctx.req.getUrlParam "year"
  let month = ctx.req.getUrlParam "month"
  let day = ctx.req.getUrlParam "day"
  return ctx.text "id=" & id & ";year=" & year & ";month=" & month & ";day=" & day

let handler = choose(
  GET >=> routep("/home/{userid : string}/blog/{year:int}/{month: int}/{day:int}") >=> urlParamHandler,
)

```

## auth

```nim
# import alpaka/auth/sessionauth

let signinHandler = handler(ctx) do: 
  let id = ctx.req.getQueryParam "id"
  let pass = ctx.req.getQueryParam "pass"
  if not ctx.signin(id, pass):
    return ctx.code Http401
  return ctx.redirect("/auth/")

# set routing
let handler = choose(
  GET >=> route("/signin") >=> signinHandler,
  GET >=> route("/auth/") >=> mustBeAuth >=> (handler(ctx) do: ctx.text "hello " & ctx.user.name),  
)

let getUser = proc(id,pass: string): AuthedUser =
  if id != "tester" or pass != "password":
    return nil
  return AuthedUser(
    id: id,
    name: id,
    role: @["normal"]
  )

handler
  .newRouter()
  .useAsyncHttpServer(8080)
  .useSessionAuth(getUser, "/signin", "cookieName", "hashKey")
  .run()


```

## serve static file 

```nim
let handler = choose(
  serveDir("/static/", "./assets/"),  
)
```

## cache

```nim
let handler = choose(
  route("/cache/") >=> asCacheable(proc():string ="etag") >=> text "cache me",  
)
```


## sub route

```nim
let postHandler = handler(ctx) do:
  let value = ctx.req.getFormParam "text"
  return ctx.text value 

let handler = choose(
  subRoute("/sub/",[
    route("/") >=> GET >=> text "hello",
    route("/") >=> POST >=> postHandler,
  ]) 
)
```
