{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        defaultPackage = pkgs.python3Packages.buildPythonPackage rec {
          name = "pixamo";
          pname = "pixamo";
          version = "0.1";
          src = ./.;
          propagatedBuildInputs = [ pkgs.python3Packages.pillow ];
        };
      });
}
