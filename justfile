release:
  @rm -rf lib/
  @mkdir -p lib/
  just build x86_64-windows-msvc
  just build aarch64-linux-gnu

translate target='native':
  @rm -rf zig-out/
  zig build --build-file dev.build.zig translate build-c -Dtarget={{target}}

build target='native': (translate target)
  @cp zig-out/lib/* lib/

test: build
  zig build --build-file dev.build.zig test --summary all

docs: 
  zig build --build-file dev.build.zig docs