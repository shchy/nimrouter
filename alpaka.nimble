# Package

version       = "0.1.0"
author        = "shch"
description   = "giraffe copy"
license       = "MIT"

# Dependencies

requires "nim >= 0.16.0"

skipDirs      = @["example"]
bin           = @["alpaka", "alpakaview", "alpakabasicauth", "alpakasessionauth"]

task clean, "clean":
    exec "rm -rf ./example/sample00/nimcache"
    exec "rm -rf ./example/sample00/app"
    exec "rm -rf ./example/sample01/nimcache"
    exec "rm -rf ./example/sample01/app"
    exec "rm -rf ./alpaka"
    exec "rm -rf ./alpakabasicauth"
    exec "rm -rf ./alpakasessionauth"
    exec "rm -rf ./alpakaview"
    exec "rm -rf ./nimcache"
task ex00, "exec sample00":
    exec "rm -f ./example/sample00/app"
    exec "nimble install -y"
    exec "nim c -r -d:release ./example/sample00/app.nim"
task ex01, "exec sample01":
    exec "rm -f ./example/sample01/app"
    exec "nimble install -y"
    exec "nim c -r -d:release ./example/sample01/app.nim"