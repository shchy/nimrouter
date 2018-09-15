# Package

version       = "0.1.0"
author        = "shch"
description   = "giraffe[F#] copy"
license       = "MIT"

# Dependencies

requires "nim >= 0.18.0"

binDir        = "bin"
srcDir        = "src"
skipDirs      = @["example", "tests"]
bin           = @["alpaka"]

task clean, "clean":
    exec "rm -rf ./example/sample00/nimcache"
    exec "rm -rf ./example/sample00/app"
    exec "rm -rf ./example/sample01/nimcache"
    exec "rm -rf ./example/sample01/app"
    exec "rm -rf ./example/sample02/nimcache"
    exec "rm -rf ./example/sample02/app"
    exec "rm -rf ./bin"
    exec "rm -rf ./src/nimcache"
    exec "rm -rf ./tests/nimcache"
    exec "rm -rf ./tests/testcommon"
    exec "rm -rf ./tests/testcontext"
    exec "rm -rf ./tests/testhandler"
    exec "rm -rf ./tests/testbasicauth"
    exec "rm -rf ./tests/testsessionauth"

task ex00, "exec sample00":
    exec "rm -f ./example/sample00/app"
    exec "nimble develop -y"
    exec "nim c -r -d:release ./example/sample00/app.nim"
task ex01, "exec sample01":
    exec "rm -f ./example/sample01/app"
    exec "nimble develop -y"
    exec "nim c -r -d:release ./example/sample01/app.nim"
task ex02, "exec sample02":
    exec "rm -f ./example/sample02/app"
    exec "nimble develop -y"
    exec "nim c -r -d:release ./example/sample02/app.nim"
