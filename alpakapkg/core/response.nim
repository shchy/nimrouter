import 
    httpcore,
    tables

type
    RouteResponse*  = ref object
        code*           : HttpCode
        headers*        : HttpHeaders
        body*           : string
        contentFilePath*: string

# backup responce
proc clone*(res: RouteResponse): RouteResponse =
    let code = res.code
    let body = res.body
    let headers = newHttpHeaders()
    let contentFilePath = res.contentFilePath

    for key in res.headers.table.keys:
        for val in res.headers.table[key]:
            headers.add(key, val)
    return RouteResponse(
        code: code,
        body: body,
        headers: headers,
        contentFilePath: contentFilePath
    )
    
proc clear*(res: RouteResponse) =
    res.code = Http500
    res.body = ""
    res.headers.clear()
    res.contentFilePath = ""
