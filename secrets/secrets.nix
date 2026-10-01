# The recipients of every agenix secret, for ragenix (`just edit-secret`).
#
# Every .age file under secrets/ is encrypted to the same keys, from
# recipients.txt, so this file lists the files by reading the directory:
# adding a secret is adding its file, and secrets added side by side never
# conflict here. home-manager/agenix.nix installs them the same way.
let
  # recipients.txt: one public key per line, # for comments.
  lines = builtins.split "\n" (builtins.readFile ./recipients.txt);
  publicKeys = builtins.filter (
    line: builtins.isString line && builtins.match "age1.*" line != null
  ) lines;

  ageFiles =
    dir: prefix:
    builtins.concatLists (
      builtins.attrValues (
        builtins.mapAttrs (
          name: type:
          if type == "directory" then
            ageFiles (dir + "/${name}") "${prefix}${name}/"
          else if builtins.match ".*\\.age" name != null then
            [ "${prefix}${name}" ]
          else
            [ ]
        ) (builtins.readDir dir)
      )
    );
in
builtins.listToAttrs (
  map (file: {
    name = file;
    value = { inherit publicKeys; };
  }) (ageFiles ./. "")
)
