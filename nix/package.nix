{ lib
, buildGoModule
, buildNpmPackage
, gcc
, sqlite
, curl
, withWebUI ? false
}:

let
  webUI = buildNpmPackage {
    pname = "ntfy-web";
    version = "2.0.0";
    src = ../web;
    npmDepsHash = "sha256-d73rymqCKalsjAwHSJshEovmUHJStfGt8wcZYN49sHY=";

    buildPhase = ''
      npm run build
      mv build/index.html build/app.html
    '';

    installPhase = ''
      mkdir -p $out
      cp -r build/* $out/
    '';
  };
in
buildGoModule {
  pname = "ntfy-sh";
  version = "2.0.0";
  src = ../.;

  vendorHash = "sha256-TpHVKrGLDRsd5AGnw2ps5WJ2mcEcXTMJnwfzk9lL584=";

  nativeBuildInputs = [ gcc ];
  buildInputs = [ sqlite ];
  nativeCheckInputs = [ curl ];

  checkFlags = [
    "-skip"
    "TestCLI_Publish_Subscribe_Poll_Real_Server|TestCLI_Publish_Wait_PID_And_Cmd|TestServer_StaticSites|TestServer_WebEnabled"
  ];

  env.CGO_ENABLED = "1";
  tags = [ "sqlite_omit_load_extension" ];

  preBuild = ''
    mkdir -p server/docs server/site
    touch server/docs/index.html
    ${if withWebUI then ''
      cp -r ${webUI}/* server/site/
      if [ -f server/site/index.html ]; then
        cp server/site/index.html server/site/app.html
      fi
    '' else ''
      touch server/site/app.html
    ''}
  '';

  ldflags = [
    "-s" "-w"
    "-X main.version=2.0.0"
  ];

  meta = with lib; {
    description = "Simple HTTP-based pub-sub notification service";
    homepage = "https://ntfy.sh";
    license = [ licenses.asl20 licenses.gpl2Only ];
    mainProgram = "ntfy";
  };
}
