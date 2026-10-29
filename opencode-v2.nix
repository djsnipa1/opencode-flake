# OpenCode v2 Package
# Fetches pre-built native binaries from npm registry @opencode/cli
# https://www.npmjs.com/package/@opencode/cli

{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, zlib
, openssl
, icu
}:

let
  version = "2.2.1";

  # Platform mapping: Nix system -> npm package name
  platformMap = {
    "x86_64-linux"   = { target = "linux-x64";      };
    "aarch64-linux"  = { target = "linux-arm64";     };
    "x86_64-darwin"  = { target = "darwin-x64";      };
    "aarch64-darwin" = { target = "darwin-arm64";     };
  };

  platformInfo = platformMap.${stdenv.hostPlatform.system} or
    (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  # Per-platform hashes from npm registry
  # Generated with:
  #   nix-prefetch-url --type sha256 https://registry.npmjs.org/@opencode/cli-${target}/-/cli-${target}-${version}.tgz
  #   nix hash to-sri --type sha256 <hash>
  hashes = {
    "linux-arm64" = "sha256-LO4SZ3wxDdFz+Z6WlSYSz2zSAxl303YuOuqmdn/Xsgs=";
    "linux-x64" = "sha256-Qs8d3ffRq63O6JWsnGZInsmUuMZQsfSuydOz59B9ml4=";
    "darwin-x64" = "sha256-zm/didVv7+TOrFjnE9ol8vfXgU1VqmjRsMPHKZYkNdM=";
    "darwin-arm64" = "sha256-selaGoKVFY6lr6BIhnqkC0IuzD6RXKlKybZMw3wsvQE=";
  };

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-${platformInfo.target}/-/cli-${platformInfo.target}-${version}.tgz";
    sha256 = hashes.${platformInfo.target};
  };

in
stdenv.mkDerivation {
  pname = "opencode2";
  inherit version;

  inherit src;

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [ makeBinaryWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  # Runtime deps for the dynamically linked binary on Linux
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    zlib
    openssl
    icu
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Extract the binary from the archive (npm packages are .tgz)
    tar -xzf $src --strip-components=1 -C $out

    # The binary is at bin/opencode in the extracted package
    if [ -f "$out/bin/opencode" ]; then
      mv $out/bin/opencode $out/bin/.opencode2-unwrapped
    elif [ -f "$out/bin/opencode.exe" ]; then
      mv $out/bin/opencode.exe $out/bin/.opencode2-unwrapped
    else
      echo "ERROR: Could not find opencode binary in extracted package"
      find $out -type f -name "opencode*" 2>/dev/null
      exit 1
    fi

    makeBinaryWrapper $out/bin/.opencode2-unwrapped $out/bin/opencode2

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenCode v2 - AI coding agent built for the terminal (v2 beta)";
    homepage = "https://opencode.ai";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "opencode2";
  };
}
