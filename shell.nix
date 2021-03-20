{ pkgs ? import <nixpkgs> { } }:

let
  mixOverlay = builtins.fetchGit {
    url = "https://github.com/hauleth/nix-elixir.git";
  };
  nixpkgs = import <nixpkgs> {
    overlays = [ (import mixOverlay) ];
  };
  erlang = pkgs.beam.packages.erlangR23;
  elixir = erlang.elixir_1_11;
in pkgs.mkShell {
  buildInputs = [
    erlang.rebar3
    elixir
    ffmpeg
  ];
}
