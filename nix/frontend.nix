# Gebaute Oberfläche (Vite) samt Übungsbildern aus catalogue/media, als statischer Baum für einen Webserver.
# Der Build läuft im Repo-Root: frontend/src importiert ../../../api/coach/core, deshalb reicht frontend/ allein nicht.
{
  lib,
  buildNpmPackage,
  fetchNpmDeps,
  nodejs_22,
}:
buildNpmPackage {
  pname = "opengym-frontend";
  version = (lib.importJSON ../frontend/package.json).version;
  src = lib.cleanSource ../.;
  npmRoot = "frontend";
  nodejs = nodejs_22;

  npmDeps = fetchNpmDeps {
    src = ../frontend;
    hash = "sha256-+lSLS4G6OMwAntUH5WAWh3CoirzDqx17XwoUPnbKnMY=";
  };
  # Kein Postinstall (sharp aus @capacitor/assets lädt libvips aus dem Netz); fürs Web-Bundle nicht nötig
  npmFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    runHook preBuild
    cd frontend && npm run build && cd ..
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r frontend/dist/. $out/
    cp -r catalogue/media $out/exercise-media
    runHook postInstall
  '';
}
