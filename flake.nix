{
  description = "Development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          pip
          bsdiff4
          tkinter
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ pythonEnv ruff jpexs zip ruffle ];
          shellHook = ''
            export PIP_PREFIX=$PWD/pip
            export PYTHONPATH="$PWD/Archipelago:$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
            export PATH="$PIP_PREFIX/bin:$PATH"
            unset SOURCE_DATE_EPOCH
          '';
        };
      }
    );
}
