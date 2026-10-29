{
  description = "Reusable glibc-override toolchain. Pins an old glibc and rebuilds a cc/stdenv against it, so downstream binaries link an older glibc ABI for wider runtime compatibility. Consumers stay ignorant of the override mechanics — they just take cc / cc_host / stdenv.";

  inputs = {
    # New nixpkgs: provides the modern toolchain (gcc, binutils, build tools).
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # Old nixpkgs: only used to source the old glibc we link against.
    nixpkgs_old = {
      url = "github:nixos/nixpkgs/nixos-20.09";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs_old
    ,
    }:
    {

      # mkGlibcOverride: the only thing a consumer needs.
      #
      # Args:
      #   localSystem  build machine system            (default "x86_64-linux")
      #   crossSystem  target system; null = native     (e.g. nixpkgs.lib.systems.examples.gnu64)
      #   pkgs         package-set selector on nixpkgs   (default "pkgs"; e.g. "pkgsStatic")
      #   overlays     extra overlays for the new pkgs   (default [])
      #   config       nixpkgs config                    (default {})
      #
      # Returns: { cc cc_host stdenv loadedPkgs oldPkgs }
      lib.mkGlibcOverride =
        { localSystem
        , crossSystem ? null
        , targetPlatform
        , buildPlatform
        , pkgs ? "pkgs"
        ,
        }:
        let
          isCross = targetPlatform != buildPlatform;
          # Args for the *new* nixpkgs: cross whenever a crossSystem is given.
          crossArgs =
            if isCross then
              {
                inherit localSystem crossSystem;
              }
            else
              {
                inherit localSystem;
              };

          # Target/cross package set (what we build downstream artifacts with).
          loadedPkgs = import nixpkgs (crossArgs);

          # Old nixpkgs cross decision must compare the *real* platforms, not just
          # "crossSystem != null". A crossSystem equal to the build platform (e.g.
          # gnu64 on x86_64-linux) is effectively native — importing old nixpkgs
          # cross in that case forces a cross-build of the old gcc/glibc, which fails.
          oldPkgs = import nixpkgs_old crossArgs;

          # Native host package sets, for tools that must run on the build machine.
          hostPkgs = import nixpkgs { inherit localSystem; };
          oldHostPkgs = import nixpkgs_old { inherit localSystem; };

          # cc: target compiler, glibc swapped for the old one.
          cc = loadedPkgs.${pkgs}.callPackage ./override_glibc.nix {
            pkgs = loadedPkgs;
            oldGlibc = oldPkgs.glibc;
          };
          # cc_host: same override, but for the native build host.
          cc_host = loadedPkgs.${pkgs}.callPackage ./override_glibc.nix {
            pkgs = hostPkgs;
            oldGlibc = oldHostPkgs.glibc;
          };
          # stdenv wired to the overridden cc — drop-in for stdenv.mkDerivation.
          stdenv = loadedPkgs.overrideCC loadedPkgs.stdenv cc;
        in
        {
          inherit
            cc
            cc_host
            stdenv
            ;
        };
    };
}
