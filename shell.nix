# shell.nix
# Define isolated environment with required tools
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  # These packages will be available only inside the nix-shell
  buildInputs = [
    pkgs.yt-dlp
    pkgs.nodejs_22
    pkgs.gnumake
    pkgs.gawk
  ];

  # Hook executed immediately after entering the shell
  shellHook = ''
    echo "========================================"
    echo "Environment is ready."
    echo "yt-dlp version: $(yt-dlp --version)"
    echo "Node.js version: $(node --version)"
    echo "========================================"
    echo "Run 'make' to start parallel downloads."
  '';
}