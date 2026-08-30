{
  description = "huggingface-hub: version-bumped ahead of nixpkgs through a Python package overlay.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    click = {
      url = "github:jgus/click-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-lib.follows = "flake-lib";
    };
    hf-xet = {
      url = "github:jgus/hf-xet-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-lib.follows = "flake-lib";
    };
  };

  outputs = { nixpkgs, flake-utils, flake-lib, click, hf-xet, ... }:
    let
      pin = import ./pin.nix;
      inherit (pin) version hash;
      source = { type = "pypi"; pname = "huggingface_hub"; format = "sdist"; };
      huggingfaceHubOverlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            huggingface-hub = pyprev.huggingface-hub.overridePythonAttrs (old: {
              inherit version;
              doCheck = false;
              dependencies = final.lib.filter
                (dependency: ! builtins.elem (dependency.pname or null) [
                  "click"
                  "hf-xet"
                  "typer"
                ])
                (old.dependencies or [ ]) ++ [
                pyfinal.click
                pyfinal.hf-xet
              ];
              src = pyfinal.fetchPypi { inherit version hash; pname = "huggingface_hub"; };
            });
          })
        ];
      };
      overlay = nixpkgs.lib.composeManyExtensions [
        click.overlays.default
        hf-xet.overlays.default
        huggingfaceHubOverlay
      ];
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            huggingface-hub = pkgs.python3.pkgs.huggingface-hub;
            default = pkgs.python3.pkgs.huggingface-hub;
            update-version = flake-lib.lib.mkUpdateVersion {
              inherit pkgs source;
              buildAttr = "huggingface-hub";
              siblings = [
                {
                  reqName = "click";
                  pypiName = "click";
                  flakeRepo = "jgus/click-flake";
                  mode = "resolve";
                }
                {
                  reqName = "hf-xet";
                  pypiName = "hf-xet";
                  flakeRepo = "jgus/hf-xet-flake";
                  mode = "resolve";
                }
              ];
              siblingRefsInPin = true;
            };
            update-branches = flake-lib.lib.mkUpdateBranches {
              inherit pkgs source;
              pinSchema = "pypi";
            };
          };
        }) // {
      overlays.default = overlay;
    };
}
