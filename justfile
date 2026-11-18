release:
  @rm -rf lib/
  @mkdir -p lib/
  just build x86_64-windows-gnu ReleaseFast
  just build aarch64-linux-gnu ReleaseFast

translate target='native' optimize='Debug':
  @rm -rf zig-out/
  zig build --build-file dev.build.zig translate build-c -Dtarget={{target}} -Doptimize={{optimize}}

build target='native' optimize='Debug': (translate target optimize)
  @cp zig-out/lib/* lib/

test: build
  zig build --build-file dev.build.zig test --summary all

docs: 
  zig build --build-file dev.build.zig docs