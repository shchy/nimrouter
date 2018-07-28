# Package

version       = "0.1.0"
author        = "shch"
description   = "giraffe copy"
license       = "MIT"

# Dependencies

requires "nim >= 0.16.0"

srcDir        = "src"
binDir        = "bin"

#bin           = @["alpaka"]

task clean, "clean":
    exec "rm -rf ./example/sample00/nimcache"
    exec "rm -rf ./example/sample00/app"
    exec "rm -rf ./example/sample01/nimcache"
    exec "rm -rf ./example/sample01/app"
    exec "rm -rf ./bin/alpaka"
    exec "rm -rf ./src/nimcache"
task ex00, "exec sample00":
    exec "rm -f ./example/sample00/app"
    exec "nimble install -y"
    exec "nim c -r -d:release ./example/sample00/app.nim"
task ex01, "exec sample01":
    exec "rm -f ./example/sample01/app"
    exec "nimble install -y"
    exec "nim c -r -d:release ./example/sample01/app.nim"