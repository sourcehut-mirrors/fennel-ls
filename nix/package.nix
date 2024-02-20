{ version ? "dirty"
, stdenv
, lua
}: stdenv.mkDerivation {
  pname = "fennel_ls";
  inherit version;

  src = ./..;

  makeFlags = [ "PREFIX=$(out)" ];

  buildInputs = [ lua ];

  doCheck = true;

}
