import 
    httpcore,
    uri,
    strutils
import 
    params

type
    IRouteRequest*  = ref object
        reqMethod*  : HttpMethod
        headers*    : HttpHeaders
        url*        : Uri
        body*       : string
        queryParams : Params
        urlParams*  : Params # todo 

proc getQueryParam*(req: IRouteRequest, key: string): string =
    if req.queryParams == nil:
        req.queryParams = newParams()   
        let query = req.url.query
        let params = query.split("&")
        for prm in params:
            let keyValue = prm.split("=")
            if keyValue.len() != 2:
                continue
            req.queryParams.setParam(keyValue[0], keyValue[1])
    return req.queryParams.getParam key

proc getUrlParam*(req: IRouteRequest, key: string): string =
    return req.urlParams.getParam key