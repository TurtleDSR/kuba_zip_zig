translate:
  zig build --build-file dev.build.zig translate build-c

build: translate
  cp zig-out/lib/* lib/

test: build
  zig build --build-file dev.build.zig test --summary all

docs: 
  zig build --build-file dev.build.zig docs