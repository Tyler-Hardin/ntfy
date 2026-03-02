{
  description = "ntfy - a simple HTTP-based pub-sub notification service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        ntfy-sh = final.callPackage ./nix/package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend overlay;
      in
      {
        packages = rec {
          ntfy = pkgs.ntfy-sh;
          ntfy-full = pkgs.callPackage ./nix/package.nix { withWebUI = true; };
          default = ntfy;
        };

        devShells.default = pkgs.mkShell {
          name = "ntfy-dev";

          buildInputs = with pkgs; [
            go
            gcc
            sqlite
            gotools
            gopls
            golangci-lint
            nodejs_22
            nodePackages.npm
            gnumake
            git
          ];

          CGO_ENABLED = "1";

          shellHook = ''
            echo "ntfy dev shell"
            echo "  Go:   $(go version)"
            echo "  Node: $(node --version)"
            echo ""
            echo "Quick build (no web/docs):"
            echo "  mkdir -p server/docs server/site && touch server/docs/index.html server/site/app.html"
            echo "  CGO_ENABLED=1 go build -tags sqlite_omit_load_extension -o ntfy ."
            echo ""
            echo "Web frontend:"
            echo "  cd web && npm install && npm run build"
          '';
        };
      }
    ) // {
      overlays.default = overlay;

      nixosModules = {
        # The upstream server module, using our package
        server = { config, lib, pkgs, ... }: {
          imports = [ "${nixpkgs}/nixos/modules/services/misc/ntfy-sh.nix" ];
          config = lib.mkIf config.services.ntfy-sh.enable {
            services.ntfy-sh.package = lib.mkDefault self.packages.${pkgs.system}.ntfy;
          };
        };

        # Client module, wrapped to default the package to this flake's build
        client = { config, lib, pkgs, ... }: {
          imports = [ ./nix/client-module.nix ];
          config = lib.mkIf config.programs.ntfy-sh.enable {
            programs.ntfy-sh.package = lib.mkDefault self.packages.${pkgs.system}.ntfy;
          };
        };

        # Convenience: both together
        default = { imports = [ self.nixosModules.server self.nixosModules.client ]; };
      };
    };
}
