# Package

version       = "0.1.1"
author        = "shch"
description   = "giraffe[F#] copy"
license       = "MIT"

# Dependencies

requires "nim >= 1.0.6"

srcDir        = "src"
skipDirs      = @["example", "tests"]

task clean, "clean":
    exec "rm -rf ./bin"
    exec "rm -rf ./tests/"
    exec "rm -f ./example/sample00/app"
    exec "rm -f ./example/sample01/app"
    exec "rm -f ./example/sample02/app"
    
task ex00, "exec sample00":
    # exec "rm -f ./example/sample00/app"
    exec "nim c -r -d:release ./example/sample00/app.nim"
task ex01, "exec sample01":
    exec "rm -f ./example/sample01/app"
    exec "nim c -r -d:release ./example/sample01/app.nim"
task ex02, "exec sample02":
    exec "rm -f ./example/sample02/app"
    exec "nim c -r -d:release ./example/sample02/app.nim"
