alyssaevans@DTO-A311:~/dotfiles/ > sudo darwin-rebuild switch --flake .#ditto --show-trace
building the system configuration...
warning: Git tree '/Users/alyssaevans/dotfiles' is dirty
error:
       … from call site
         at /nix/store/zdi8af86f5yr0a5z51zis17c9aq15cpg-source/eval-config.nix:88:14:
           87|     inherit (configuration._module.args) pkgs;
           88|     system = configuration.config.system.build.toplevel;
             |              ^
           89|     extendModules = args: withExtraAttrs (configuration.extendModules args);

       … while calling anonymous lambda
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/types.nix:879:22:
          878|                 value = mapAttrs (
          879|                   n: v:
             |                      ^
          880|                   if lazy then

       … while evaluating the attribute 'optionalValue.value'
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1256:5:
         1255|
         1256|     optionalValue = if isDefined then { value = mergedValue; } else { };
             |     ^
         1257|   };

       … while evaluating a branch condition
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1256:21:
         1255|
         1256|     optionalValue = if isDefined then { value = mergedValue; } else { };
             |                     ^
         1257|   };

       … while evaluating the attribute 'values'
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1186:9:
         1185|       {
         1186|         values = defsSorted;
             |         ^
         1187|         inherit (defsFiltered) highestPrio;

       … while evaluating a branch condition
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1180:11:
         1179|           # Avoid sorting if we don't have to.
         1180|           if any (def: def.value._type or "" == "order") defsFiltered.values then
             |           ^
         1181|             sortProperties defsFiltered.values

       … while calling the 'any' builtin
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1180:14:
         1179|           # Avoid sorting if we don't have to.
         1180|           if any (def: def.value._type or "" == "order") defsFiltered.values then
             |              ^
         1181|             sortProperties defsFiltered.values

       … while evaluating the attribute 'values'
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1360:7:
         1359|     {
         1360|       values = concatMap (def: if getPrio def == highestPrio then [ (strip def) ] else [ ]) defs;
             |       ^
         1361|       inherit highestPrio;

       … while calling the 'concatMap' builtin
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1360:16:
         1359|     {
         1360|       values = concatMap (def: if getPrio def == highestPrio then [ (strip def) ] else [ ]) defs;
             |                ^
         1361|       inherit highestPrio;

       … while calling the 'concatMap' builtin
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1160:26:
         1159|         # Process mkMerge and mkIf properties.
         1160|         defsNormalized = concatMap (
             |                          ^
         1161|           m:

       … while calling anonymous lambda
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1161:11:
         1160|         defsNormalized = concatMap (
         1161|           m:
             |           ^
         1162|           map (

       … while calling the 'map' builtin
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1162:11:
         1161|           m:
         1162|           map (
             |           ^
         1163|             value:

       … while evaluating definitions from `/nix/store/zdi8af86f5yr0a5z51zis17c9aq15cpg-source/modules/system':

       … from call site
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1171:80:
         1170|               }
         1171|           ) (addErrorContext "while evaluating definitions from `${m.file}':" (dischargeProperties m.value))
             |                                                                                ^
         1172|         ) defs;

       … while calling 'dischargeProperties'
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1311:5:
         1310|   dischargeProperties =
         1311|     def:
             |     ^
         1312|     if def._type or "" == "merge" then

       … while evaluating a branch condition
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/modules.nix:1312:5:
         1311|     def:
         1312|     if def._type or "" == "merge" then
             |     ^
         1313|       concatMap dischargeProperties def.contents

       … while evaluating the attribute 'value'
         at /nix/store/xzl5dhddgjxp2p18h5qpkhvlkp8128j1-source/lib/types.nix:819:15:
          818|               inherit (def) file;
          819|               value = v;
             |               ^
          820|             }) def.value

       … from call site
         at /nix/store/zdi8af86f5yr0a5z51zis17c9aq15cpg-source/modules/system/default.nix:83:29:
           82|
           83|     system.build.toplevel = throwAssertions (showWarnings (stdenvNoCC.mkDerivation ({
             |                             ^
           84|       name = "darwin-system-${cfg.darwinLabel}";

       … while calling 'throwAssertions'
         at /nix/store/zdi8af86f5yr0a5z51zis17c9aq15cpg-source/modules/system/default.nix:13:21:
           12|
           13|   throwAssertions = res: if (failedAssertions != []) then throw "\nFailed assertions:\n${concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}" else res;
             |                     ^
           14|   showWarnings = res: foldr (w: x: builtins.trace "warning: ${w}" x) res config.warnings;

       … while calling the 'throw' builtin
         at /nix/store/zdi8af86f5yr0a5z51zis17c9aq15cpg-source/modules/system/default.nix:13:59:
           12|
           13|   throwAssertions = res: if (failedAssertions != []) then throw "\nFailed assertions:\n${concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}" else res;
             |                                                           ^
           14|   showWarnings = res: foldr (w: x: builtins.trace "warning: ${w}" x) res config.warnings;

       error:
       Failed assertions:
       - Previously, some nix-darwin options applied to the user running
       `darwin-rebuild`. As part of a long‐term migration to make
       nix-darwin focus on system‐wide activation and support first‐class
       multi‐user setups, all system activation now runs as `root`, and
       these options instead apply to the `system.primaryUser` user.

       You currently have the following primary‐user‐requiring options set:

       * `system.defaults.NSGlobalDomain.AppleShowAllExtensions`
       * `system.defaults.NSGlobalDomain.InitialKeyRepeat`
       * `system.defaults.NSGlobalDomain.KeyRepeat`
       * `system.defaults.NSGlobalDomain.NSAutomaticCapitalizationEnabled`
       * `system.defaults.NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled`
       * `system.defaults.dock.autohide`
       * `system.defaults.dock.orientation`
       * `system.defaults.dock.persistent-apps`
       * `system.defaults.dock.show-recents`
       * `system.defaults.dock.tilesize`
       * `system.defaults.finder.AppleShowAllExtensions`
       * `system.defaults.finder.FXEnableExtensionChangeWarning`
       * `system.defaults.finder.ShowPathbar`
       * `system.defaults.finder.ShowStatusBar`

       To continue using these options, set `system.primaryUser` to the name
       of the user you have been using to run `darwin-rebuild`.

       If you run into any unexpected issues with the migration, please
       open an issue at <https://github.com/nix-darwin/nix-darwin/issues/new>
       and include as much information as possible.