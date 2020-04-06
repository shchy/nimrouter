import 
  models



proc getUsers*() : seq[User] =
  @[
    User(id:"test", password: "test", name: "tester"),
  ]