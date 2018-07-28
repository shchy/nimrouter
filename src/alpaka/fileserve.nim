import 
    httpcore,
    uri,
    strutils,
    sequtils,
    cgi,
    os,
    mimetypes
import
    core,
    routing


proc serveDir*(path,localPath: string): RouteHandler =
    # todo path must be terminate "/"
    let mimeDB = newMimetypes()
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
            
            if not existsFile(localFilePath):
               return abort 
            if not os.getFilePermissions(localFilePath).contains(os.fpOthersRead):
                return ctx.code Http403
            
            #let fileSize = os.getFileSize(localFilePath)
            let ext = ($localFilePath).splitFile.ext
            let mime = mimeDB.getMimeType(ext[1..ext.len()-1])
            let file = readFile($localFilePath)
            ctx.setHeader("Content-Type", mime)
            #ctx.setHeader("Content-Length", $fileSize)

            # todo large file
            return ctx.text file
            
            



                

                
            
            


                