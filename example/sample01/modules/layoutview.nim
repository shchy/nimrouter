import 
    emerald,
    sequtils

proc header*(title: string) {.html_mixin.} =
    head:
        meta(charset="utf-8"):""
        meta(content="width=device-width,initial-scale=1", name="viewport"):""
        title: title

        link(rel="stylesheet", href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css"): ""
        link(rel="stylesheet", href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap-theme.min.css"): ""
        script(`type`="text/javascript", src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"): ""
        put mixin_content()
