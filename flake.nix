{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    zig.url = "github:mitchellh/zig-overlay";
    zig.inputs.nixpkgs.follows = "nixpkgs";
    zls.url = "github:zigtools/zls";
    zls.inputs.nixpkgs.follows = "nixpkgs";
    zls.inputs.zig-overlay.follows = "zig";
    nixgl.url = "github:nix-community/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixgl,
      nixpkgs,
      zig,
      zls,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [ nixgl.overlay ];
        }
      );
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
          zigPinned = zig.packages.${system}."0.15.1";
          zlsPinned = zls.packages.${system}.zls.overrideAttrs (prev: {
            buildInputs = [ zigPinned ];
          });
          inherit (pkgs) lib stdenv;

          # Wrap godot with nixGL for non-NixOS systems (Mesa for AMD/Intel)
          godotWrapped =
            if stdenv.hostPlatform.isLinux then
              pkgs.writeShellScriptBin "godot" ''
                exec ${pkgs.nixgl.nixGLMesa}/bin/nixGLMesa ${pkgs.godot}/bin/godot "$@"
              ''
            else
              pkgs.godot;
        in
        {
          default = pkgs.mkShell {
            buildInputs =
              [
                godotWrapped
                pkgs.lldb
                zigPinned
                zlsPinned
              ];
          };
        }
      );
    };
}
