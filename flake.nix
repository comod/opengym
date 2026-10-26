{
  description = "openGym: selbst gehosteter Trainings- und Gewichtstracker (Fork von DuarteSantos8/openGym)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      frontend = pkgs.callPackage ./nix/frontend.nix { };
      api = pkgs.callPackage ./nix/api.nix { };
    in
    {
      packages.${system} = {
        inherit frontend api;
        default = api;
      };

      nixosModules.default = import ./nix/module.nix { inherit self; };

      # Hydra baut alle Pakete; dazu gehört eine eingecheckte flake.lock
      hydraJobs = self.packages.${system};

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_22
          just
          prefetch-npm-deps
        ];
      };
    };
}
