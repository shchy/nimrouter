# Package

version       = "0.1.0"
author        = "Anonymous"
description   = "test"
license       = "MIT"

# Dependencies

requires "nim >= 0.16.0"

bin           = @["app"]
srcDir        = "src"
binDir        = "bin"

task run, "exec":
    exec "rm ./bin/app"
    exec "nimble build"
    exec "./bin/app"