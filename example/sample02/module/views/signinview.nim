import 
    alpaka/view,
    layout


proc view*(): string = 
    layout("signin",[
        meta(name="viewport", content="width=device-width, initial-scale=1, shrink-to-fit=no"),
        link(href="/static/css/signin.css", rel="stylesheet"), 
        ],
        body(class="text-center",
            form(class="form-signin", `method`="POST",
                h1(class="mb-4", width="72", height="72", "&#x1F6C0;"),
                h1(class="h3 mb-3 font-weight-normal", "Please sign in"),
                label(`for`="inputID", class="sr-only", "ID"),
                input(id="inputID", name="id", class="form-control", placeholder="Your ID", `required`, `autofocus`),
                label(`for`="inputPassword", class="sr-only", "Password"),
                input(`type`="password", id="inputPassword", name="password", class="form-control", placeholder="Password", `required`),
                `div`(class="checkbox mb-3",
                    label(
                        input(`type`="checkbox", value="true", name="isRemember", " Remember me")
                    ),
                ),
                button(class="btn btn-lg btn-primary btn-block", `type`="submit", "Sign in"),
                p(class="mt-5 mb-3 text-muted", "&copy; 2017-2018")
            )
        )
    )
    
