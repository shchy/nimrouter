import 
    emerald,
    sequtils,
    layoutview

proc viewTmpl() {.html_templ.} =
    html(lang="en"):
        call_mixin header("example"):
            link(rel="stylesheet", href="/static/signin.css"): ""
        body:
            `div`(class="container"):
                form(class="form-signin", action="/signin", `method`="POST"):
                    h2(class="form-signin-heading"):"Please sign in"
                    label(`for`="inputEmail", class="sr-only"):"Email address"
                    input(`type`="email", id="inputEmail", class="form-control", placeholder="Email address"):""
                    label(`for`="inputPassword", class="sr-only"): "Password"
                    input(`type`="password", id="inputPassword", class="form-control", placeholder="Password"):""
                    `div`(class="checkbox"):
                        label:
                            input(`type`="checkbox", value="remember-me"): "Remember me"
                    button(class="btn btn-lg btn-primary btn-block", `type`="submit"):"Sign in"
  
proc view*(): string =
    var ss = newStringStream()
    var tmpl = newViewTmpl()
    tmpl.render(ss)
    ss.flush()
    return ss.data
        
            