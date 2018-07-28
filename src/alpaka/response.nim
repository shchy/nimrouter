import 
    httpcore

type
    RouteResponse*  = ref object
        code*       : HttpCode
        headers*    : HttpHeaders
        body*       : string
