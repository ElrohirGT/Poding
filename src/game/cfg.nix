# default.nix
{pkgs ? import <nixpkgs> {}}: let
  tomlFormat = pkgs.formats.toml {};
in
  tomlFormat.generate "cfg.toml" {
    ScreenWidth = 1080;
    ScreenHeight = 720;
    FpsCap = 60;
    BackgroundColor = [74 88 89 255];

    GameRectangle = [100 100 620 480];
  }
