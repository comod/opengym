# Backend: Node ohne Framework, Passkeys und Nutzerdaten unter DATA_DIR. Ohne AI-Coach-Laufzeit (optionalDependencies
# bleiben weg), wie das Standard-Image.
{
  lib,
  buildNpmPackage,
  nodejs_22,
  makeWrapper,
}:
buildNpmPackage {
  pname = "opengym-api";
  version = (lib.importJSON ../api/package.json).version;
  src = lib.cleanSource ../api;
  nodejs = nodejs_22;
  npmDepsHash = "sha256-Sl1UycY3S2gwMZPNcz8K0xqx4v1rp0v07fmyE8KqwSo=";
  npmFlags = [
    "--omit=dev"
    "--omit=optional"
  ];
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/opengym-api $out/bin
    cp -r *.js coach openapi.yaml package.json node_modules $out/lib/opengym-api/
    makeWrapper ${lib.getExe nodejs_22} $out/bin/opengym-api \
      --add-flags $out/lib/opengym-api/server.js \
      --set NODE_ENV production
    runHook postInstall
  '';

  meta.mainProgram = "opengym-api";
}
