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
  version = "2.1.1";

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
    "linux-x64"      = "sha256-ZFkQV+pZPpoRN01GMMIkmTDY8zWYrws+AhN0k4YKsXs=";
    "linux-arm64"    = "sha256-z6OuY2P8MILwMHIpcGnYH1NVmnYTcf20tW/mv6AcoGY=";
    "darwin-x64"     = "sha256-BcBdEg48VLNqNEm1oTD+GknFvm2coAibw02ddsc3YqI=";
    "darwin-arm64"   = "sha256-ln19YcKv0a+nOzfQy2ko4zMkZlqjoBOv/FAC+fCCims=";
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