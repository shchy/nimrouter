import
    macros,
    sequtils,
    strutils

proc escape*(v: string): string =
    v.replace("&", "&amp;")
    .replace("<", "&lt;")
    .replace(">", "&gt;")
    .replace("\"", "&quot;")
    .replace("'", "&#x27;")
    .replace("\\", "&#x2F;")

proc getIdent(e: NimNode): string =
    case e.kind
        of nnkIdent: 
            result = $e
        of nnkAccQuoted:
            result = getIdent(e[0])
        else: error("is not ident" & toStrLit(e).strVal)

template tag*(name: untyped): untyped =
    macro name*(x: varargs[untyped]): untyped =
        var x = callsite()
        # echo treerepr(x)
        # echo macros.LineInfo

        let tagName = getIdent(x[0])
        let tails = x.toSeq()[1..<x.len()]#x.toSeq().filter do (n:NimNode) -> bool : n != x[0] 
        let attrs = 
            tails.filter do (n:NimNode) -> bool : 
                n.kind == nnkExprEqExpr #or n.kind == nnkIdent
        let inners =
            tails.filter do (n:NimNode) -> bool :
                not attrs.contains(n)

        # <tagname        
        result = newNimNode(nnkBracket, x)
        result.add(newStrLitNode("<"))
        result.add(newStrLitNode(escape(tagname)))
        
        # <tagname a="b" c="d" e
        for a in attrs:
            case a.kind:
                of nnkExprEqExpr: 
                    result.add(newStrLitNode(" "))
                    result.add(newStrLitNode(escape(getIdent(a[0])) ))
                    result.add(newStrLitNode("=\""))
                    result.add(a[1])
                    result.add(newStrLitNode("\""))
                # of nnkIdent: 
                #     result.add(newStrLitNode(" "))
                #     result.add(newStrLitNode(escape(getIdent(a)) ))
                else: discard
        
        # is any inner
        if inners.len() == 0:
            # <tagname a="b" c="d" e />
            result.add(newStrLitNode(" />"))
        else:
            # <tagname a="b" c="d" e>
            result.add(newStrLitNode(">"))
            # <tagname a="b" c="d" e>inners
            for inner in inners:
                result.add(inner)
            # <tagname a="b" c="d" e>inners</tagname>
            result.add(newStrLitNode("</" & escape(tagname) & ">"))

        result = nestList(toNimIdent("&"), result)

include tags

when isMainModule:
    let pp = proc(t: string, b: string): string =
        html(a=t,
            head(
                title(t)
            ),
            body(b)
        )
    let bd = proc(name: string): string =
        pp("title", 
            `div`(class="container",
                h1(class="","Home"),
                label(name)
            )
        ) 
    
    echo bd("name")
