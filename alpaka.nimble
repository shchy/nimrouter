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
    exec "rm -rf ./example/nimcache"
    exec "rm -rf ./example/app"
    exec "rm -rf ./bin/alpaka"
    exec "rm -rf ./src/nimcache"
task run, "exec":
    exec "rm -f ./example/app"
    exec "nimble install -y"
    exec "nim c -r -d:release --threads:on ./example/app.nim"