import 
    emerald,
    sequtils

proc header*(title: string) {.html_mixin.} =
    head:
        meta(charset="utf-8"):""
        meta(content="width=device-width,initial-scale=1", name="viewport"):""
        title: title

        link(rel="stylesheet", href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"): ""
        link(rel="stylesheet", href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap-theme.min.css"): ""
        
        script(`type`="text/javascript", src="https://code.jquery.com/jquery-3.3.1.slim.min.js"): ""
        script(`type`="text/javascript", src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js"): ""
        script(`type`="text/javascript", src="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/js/bootstrap.min.js"): ""
        put mixin_content()
