import 
    sequtils

type
    User*   = object
        id*       : string
        name*     : string
        password* : string


proc getUsers*() : seq[User] =
    @[
        User(id:"test", password: "test", name: "tester"),
    ]