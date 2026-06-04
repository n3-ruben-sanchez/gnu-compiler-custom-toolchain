{ pkgs, oldGlibc }:
let
  cc' = with pkgs.pkgsBuildBuild;
    wrapCCWith {
      cc = gcc-unwrapped;
      libc = oldGlibc;
      bintools = wrapBintoolsWith {
        bintools = binutils-unwrapped;
        libc = oldGlibc;
      };
    };
  cc = with pkgs.buildPackages;
    wrapCCWith {
      cc = gcc-unwrapped.override {
        stdenv = pkgs.overrideCC pkgs.buildPackages.stdenv cc';
        libcCross = oldGlibc;
      };
      libc = oldGlibc;
      bintools = wrapBintoolsWith {
        bintools = binutils-unwrapped;
        libc = oldGlibc;
      };
    };
in cc.overrideAttrs (oldAttrs: { name = "gcc-glibc-overrode"; })
