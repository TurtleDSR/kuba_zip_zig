translate:
  zig build translate build-c

build: translate
  @[ -d .build/lib/ ] || mkdir -p .build/lib/
  cp -r src/* .build/lib/
  cp zig-out/lib/zip_c.lib .build/
  cp build.zig.zon .build/lib/
  tar -czvf .build/zip.tar.gz -C .build/lib/ .

test: build
  zig build test --summary all
