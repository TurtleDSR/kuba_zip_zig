translate:
  zig build translate build-c

build: translate
  @[ -d .build/lib/zip/ ] || mkdir -p .build/lib/zip/
  cp -r src/* .build/lib/zip/
  cp zig-out/lib/zip_c.lib .build/lib/

test: build
  zig build test --summary all
