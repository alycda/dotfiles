# Lists what a darwin configuration gives a Mac, by category, as names only.
{ flake, host, user }:
let
  f = builtins.getFlake flake;
  c = f.darwinConfigurations.${host}.config;
  hm = c.home-manager.users.${user};
  lib = f.inputs.nixpkgs.lib;
  sort = builtins.sort builtins.lessThan;
  try = x: let r = builtins.tryEval x; in if r.success then r.value else "<error>";
  pname = p: p.pname or (builtins.parseDrvName (p.name or "?")).name;
  names = ps: sort (lib.unique (map pname ps));
  enabled = set: sort (builtins.filter (n: try ((set.${n}.enable or false) == true) == true) (builtins.attrNames set));
  # system.defaults: only the options that are set, as dotted paths.
  setPaths = prefix: v:
    if builtins.isAttrs v && !(lib.isDerivation v) then
      lib.concatLists (lib.mapAttrsToList (k: x: setPaths "${prefix}.${k}" (try x)) v)
    else if v == null then [ ] else [ prefix ];
in
{
  system = {
    packages = names c.environment.systemPackages;
    programs = enabled c.programs;
    services = enabled c.services;
    launchdDaemons = sort (builtins.attrNames c.launchd.daemons);
    launchdUserAgents = sort (builtins.attrNames c.launchd.user.agents);
    defaults = sort (setPaths "system.defaults" c.system.defaults);
    etc = sort (builtins.attrNames (lib.filterAttrs (n: v: v.enable) c.environment.etc));
    nixSettings = sort (builtins.attrNames c.nix.settings);
    variables = sort (builtins.attrNames c.environment.variables);
  };
  homebrew = {
    enable = c.homebrew.enable;
    onActivation = { inherit (c.homebrew.onActivation) cleanup autoUpdate upgrade; };
    taps = sort (map (t: t.name) c.homebrew.taps);
    brews = sort (map (b: b.name) c.homebrew.brews);
    casks = sort (map (b: b.name) c.homebrew.casks);
  };
  home = {
    packages = names hm.home.packages;
    programs = enabled hm.programs;
    services = enabled hm.services;
    files = sort (map (x: x.target) (builtins.filter (x: x.enable) (builtins.attrValues hm.home.file)));
    sessionVariables = sort (builtins.attrNames hm.home.sessionVariables);
    sessionPath = hm.home.sessionPath;
    activation = sort (builtins.attrNames hm.home.activation);
    launchdAgents = sort (builtins.attrNames (lib.filterAttrs (n: v: v.enable) hm.launchd.agents));
    secrets = sort (builtins.attrNames hm.age.secrets);
  };
}
