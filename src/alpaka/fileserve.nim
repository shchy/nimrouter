import 
    httpcore,
    uri,
    strutils,
    sequtils,
    os
import
    core,
    routing


proc serveDir*(path,localPath: string): RouteHandler =
    # todo path must be terminate "/"
    var localPath = localPath
    if not localPath.isAbsolute():
        localPath = $(parseUri(getAppDir()) / localPath.replace("./","") )
    return proc(next: RouteFunc): RouteFunc =
        return proc(ctx: RouteContext): RouteResult =
            if not ctx.req.url.path.startsWith(path):
                return abort
            
            let reqFilePath = 
                ctx.req.url.path[path.len()..ctx.req.url.path.len()-1]
            let localFilePath = joinPath(localPath, reqFilePath)
            
            return ctx.sendFile(localFilePath)
            
            



                

                
            
            


                