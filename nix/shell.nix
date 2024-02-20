{ callPackage
, fennel_ls ? callPackage ./package.nix { }
, mkShell
}: mkShell {
  buildInputs = fennel_ls.buildInputs or [ ];
  nativeBuildInputs = fennel_ls.nativeBuildInputs or [ ];
}
