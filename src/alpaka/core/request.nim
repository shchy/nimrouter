import 
    httpcore,
    uri,
    strutils,
    cgi
import 
    params
    
type
    RouteRequest*  = ref object
        reqMethod*  : HttpMethod
        headers*    : HttpHeaders
        url*        : Uri
        body*       : string
        queryParams : Params
        formParams  : Params
        urlParams*  : Params # todo 

proc parseParams(query: string): Params =
    result = newParams()
    try:    
        let params = query.split("&")
        for prm in params:
            let keyValue = prm.split("=")
            if keyValue.len() != 2:
                continue
            let key = decodeUrl keyValue[0]
            let value = decodeUrl keyValue[1]
            result.setParam(key, value)
    finally:
        return result

proc getQueryParam*(req: RouteRequest, key: string): string =
    if req.queryParams == nil:
        req.queryParams = parseParams(req.url.query)
    return req.queryParams.getParam key

proc getFormParam*(req: RouteRequest, key: string): string =
    if req.formParams == nil:
        req.formParams = parseParams(req.body)
    return req.formParams.getParam key

proc getUrlParam*(req: RouteRequest, key: string): string =
    return req.urlParams.getParam key
