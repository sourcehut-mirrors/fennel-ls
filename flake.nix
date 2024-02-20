{
  description = "A language server for fennel";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (flake-utils.lib) mkApp;
        inherit (pkgs) callPackage;
      in
      {
        packages = {
          fennel_ls = callPackage ./nix/package.nix {
            version = self.shortRev or self.shortDirtyRev or self.lastModifiedDate;
          };
          default = self.packages.${system}.fennel_ls;
        };

        devShells = {
          fennel_ls = callPackage ./nix/shell.nix {
            fennel_ls = self.packages.${system}.fennel_ls;
          };

          default = self.devShells.${system}.fennel_ls;
        };

        apps = rec {
          fennel_ls = mkApp {
            drv = self.packages.${system}.fennel_ls;
            exePath = "/bin/fennel-ls";
          };
          default = self.apps.${system}.fennel_ls;
        };
      }
    );
}
