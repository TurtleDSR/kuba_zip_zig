translate:
  zig build translate build-c

build: translate
  cp zig-out/lib/* lib/

test: build
  zig build test --summary all

docs: 
  zig build test docs --summary all