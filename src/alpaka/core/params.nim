import 
    tables,
    strutils

type
    Params* = ref object
        data        : Table[string, string]

proc newParams*(): Params =
    return Params(
        data        : initTable[string, string]()       
    )

proc getParam*(prms: Params, key: string): string =
    result = prms.data.getOrDefault(key)
    if result.isNilOrWhitespace:
        result = ""

proc setParam*(prms: Params, key, value: string) =
    prms.data[key] = value

proc clone*(prms: Params): Params =
    var data : seq[tuple[a:string, b:string]] = @[]
    for key in prms.data.keys:
        data.add((key, prms.data[key]))
    return Params(
        data        : data.toTable()
    )
