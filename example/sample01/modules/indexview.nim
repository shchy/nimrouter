import 
    sequtils,
    layoutview,
    alpaka/view

# proc signinViewTmpl(): string =
#     layout(
#         "example01",

#     )
#     html(lang="en"):
#         call_mixin header("example"):
#             link(rel="stylesheet", href="/static/signin.css"): ""
#         body:
#             `div`(class="container"):
#                 form(class="form-signin", action="/signin", `method`="POST"):
#                     h2(class="form-signin-heading"):"sign in"
#                     label(`for`="inputID", class="sr-only"):"Email address"
#                     input(`type`="text", id="inputID", name="id", class="form-control", placeholder="ID"):""
#                     label(`for`="inputPassword", class="sr-only"): "Password"
#                     input(`type`="password", id="inputPassword", name="password", class="form-control", placeholder="Password"):""
#                     # `div`(class="checkbox"):
#                     #     label:
#                     #         input(`type`="checkbox", name="isRemember", value="remember-me"): "Remember me"
#                     button(class="btn btn-lg btn-primary btn-block", `type`="submit"):"Sign in"
  
# proc signinView*(): string =
#     var ss = newStringStream()
#     var tmpl = newsigninViewTmpl()
#     tmpl.render(ss)
#     ss.flush()
#     return ss.data
        
proc homeView*(name:string): string =
    layout("example01",
        `div`(class="container",
            h1(class="","Home"),
            label(name)
        )
    )
        
            