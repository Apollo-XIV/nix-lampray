{
  description = "Linux Application Modding Platform";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        lampray = with final; stdenv.mkDerivation rec {
          pname = "lampray";
          inherit version;

          src = ./.;

          nativeBuildInputs = [
            cmake
            ninja
            gcc
            SDL2
            curl
            lz4   # Include LZ4 compression library
            p7zip # Include 7zip
            pkg-config
          ];

          buildInputs = [
            SDL2
            curl
            lz4   # Include LZ4 compression library
            p7zip # Include 7zip
            pkg-config
            unzip
          ];

          # Locate the 7z.so path from Nix store
          bit7zLibaryLocation = "${p7zip}/lib/p7zip/7z.so";

# Instructions to build the project using the build.sh script
          buildPhase = ''
          
            # Ensure the build directory is present and move files into it
            mkdir -p $TMPDIR/build
            cp -r ${src}/* $TMPDIR/build

            # Change directory to the build directory
            cd $TMPDIR/build

            # Run the build script in the build directory
            echo "Running build.sh"
            # ./setup.sh
            # mkdir -p ./build
            cat build.sh

            BUILD_TYPE=$${1:-Debug}

            cmake -DCMAKE_BUILD_TYPE=$$BUILD_TYPE -DCMAKE_MAKE_PROGRAM=ninja -B ./build -G Ninja -S ./

            # do ninja things
            cd ./build || exit 1 # exit if build directory doesn't exist
            ninja

            echo "📦 Build complete"
          '';

          # Install the binary into the nix store
          installPhase = ''
            echo "Copying Lampray binary to the nix store"
            mkdir -p $out/bin
            cp $TMPDIR/build/build/Lampray $out/bin/Lampray
            # Copy default config if it exists, or generate one

            # Set LD_LIBRARY_PATH for required libraries
            export LD_LIBRARY_PATH=${lib.makeLibraryPath [ lz4 p7zip SDL2 ]}:$LD_LIBRARY_PATH

            # Run Lampray from ~/Lampray to generate initial files
          '';

          # Set LD_LIBRARY_PATH to ensure runtime library linking
          shellHook = ''
            export LD_LIBRARY_PATH=${lib.makeLibraryPath [ lz4 ]}:$LD_LIBRARY_PATH
          '';
          # Add other build-time dependencies if needed
        };

        lampw = with final; writeShellScriptBin "lampw" ''
            #!/usr/bin/env bash

            # Ensure Lampray directory exists
            mkdir -p ~/.lampray/Lamp_Data/Config

            # Set LD_LIBRARY_PATH for required libraries
            export LD_LIBRARY_PATH=${lib.makeLibraryPath [ lz4 p7zip SDL2 ]}:$LD_LIBRARY_PATH

            # Run Lampray from ~/Lampray
            cd ~/.lampray

            echo "test" >> test
            # Check if config.mdf was generated and modify it
            CONFIG_FILE=~/.lampray/Lamp_Data/Config/conf.mdf
            if [ -f "$CONFIG_FILE" ]; then
              # Modify bit7zLibraryLocation
              sed -i 's|<bit7zLibaryLocation></bit7zLibaryLocation>|<bit7zLibaryLocation>${p7zip}/lib/p7zip/7z.so</bit7zLibaryLocation>|' "$CONFIG_FILE"
            fi

            exec ${lampray}/bin/Lampray "$@"

          '';
      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        let
          lamprayBin = nixpkgsFor.${system}.lampray;
          lampwBin = nixpkgsFor.${system}.lampw;
        in
        with nixpkgsFor.${system}; rec {
          lampray = lamprayBin;
          lampw = lampwBin;
        }
      );

      # The default package for 'nix build'.
      defaultPackage = forAllSystems (system: self.packages.${system}.lampw);

      # NixOS module, if applicable.
      nixosModules.lampray =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          environment.systemPackages = [ pkgs.lampray ];

          # systemd.services = { ... };
        };

      # Development shell definition
      devShell = forAllSystems (system:
        with nixpkgsFor.${system};
        stdenv.mkDerivation {
          name = "devshell";
          buildInputs = [
            cmake
            ninja
            gcc
            SDL2
            curl
            lz4
            p7zip
            
          ];
          shellHook = ''
            export LD_LIBRARY_PATH=${lib.makeLibraryPath [ lz4 ]}:$LD_LIBRARY_PATH
          '';
        }
      );
    };
}

