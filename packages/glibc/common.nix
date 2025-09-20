{ lib
, version
, old
, new
, patches ? [ ]
, backportPatches ? [ ]
, ...
}@args:

let
  extraArgs = removeAttrs args [
    "lib"
    "old"
    "new"
    "patches"
    "backportPatches"
    "NIX_CFLAGS_COMPILE"
  ];
in
new.overrideAttrs (drv:
  let
    oldEnv = drv.env or {};
    # склеим возможные предыдущие значения из env и с верхнего уровня
    prev = lib.concatStringsSep " " (lib.filter (s: s != "") [
      (oldEnv.NIX_CFLAGS_COMPILE or "")
      (drv.NIX_CFLAGS_COMPILE or "")
    ]);
    merged = lib.concatStringsSep " " (lib.filter (s: s != "") [
      prev
      "-Wno-error=implicit-int"
    ]);
in
({
  inherit (old) name src configureFlags postPatch;

  patches =
    let
      oldPatches = old.patches or [ ];
      newPatches = lib.filter
        (patch: lib.elem (baseNameOf patch) backportPatches)
        (drv.patches or [ ]);
    in
    oldPatches ++ newPatches ++ patches;

  preBuild = old.preBuild or "";

  env = oldEnv // {
     NIX_CFLAGS_COMPILE = merged;
  };

  # Prevent compatiblity symlinks for deleted files overwriting the actual files
  # in older packages.
  # https://discourse.nixos.org/t/linking-issue-with-libpthread-from-glibc-2-17/34601
  postInstall = let
   pi0 = (old.postInstall or (drv.postInstall or ""));
   lines = lib.splitString "\n" pi0;
   filtered = lib.concatStringsSep "\n" (lib.filter (l: !(lib.hasInfix "localedata/install-locale-files" l)) lines);
  in ''
    ln() {
      local dst="''${@: -1}"
      if [[ "$dst" == *.so && -f "$dst" ]]; then
        return
      fi
      command ln "$@"
    }

    ${filtered}

    unset -f ln
  '';

} // extraArgs))
