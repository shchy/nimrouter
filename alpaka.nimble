# Package

version       = "0.1.0"
author        = "shch"
description   = "giraffe copy"
license       = "MIT"

# Dependencies

requires "nim >= 0.16.0"

srcDir        = "src"
binDir        = "bin"

task run, "exec":
    exec "rm -f ./example/app"
    exec "nimble install -y"
    exec "nim c -r ./example/app.nim"