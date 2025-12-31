# Nix-Darwin + Home-Manager Setup Guide

## Why `lib.mkForce` is Required

### The Problem

When using home-manager with nix-darwin in a flake-based configuration, you may encounter this error:

```
error: A definition for option `home-manager.users.USERNAME.home.homeDirectory' is not of type `absolute path'. Definition values:
- In `/nix/store/.../nixos/common.nix': null
```

### Root Cause

This issue is caused by a **breaking change in home-manager** (not nix-darwin or flakes):

1. **Home-manager's internal behavior changed** around version 20.09+
   - Prior to 20.09: `home.homeDirectory` had a default value of `builtins.getEnv "HOME"`
   - After 20.09: **No default value** is set when `home.stateVersion >= "20.09"`

2. **The conditional logic** in home-manager's `modules/home-environment.nix`:
   ```nix
   home.homeDirectory = lib.mkIf (lib.versionOlder config.home.stateVersion "20.09") (
     lib.mkDefault (builtins.getEnv "HOME")
   );
   ```

   This means: if your `home.stateVersion` is `"24.05"` (or any version >= 20.09), **no default is set**.

3. **Module evaluation order issue**
   - When home-manager evaluates modules in nix-darwin, something in the internal evaluation chain sets `home.homeDirectory` to `null` before your explicit value is applied
   - This `null` value has **default priority** (not the lowest priority)
   - Your explicit `home.homeDirectory = "/Users/username"` also has **default priority**
   - When two definitions have the same priority and one is `null`, Nix can't determine which to use

### Why This Doesn't Happen in Standalone Home-Manager

In standalone home-manager configurations (using `home-manager.lib.homeManagerConfiguration`), the module evaluation happens differently:
- The user's config is evaluated in a more direct context
- There's no intermediate nix-darwin layer setting default values
- The explicit values in your profile take precedence naturally

### The Solution: `lib.mkForce`

Using `lib.mkForce` gives your value **the highest priority** (priority 50), which:
1. Overrides any conflicting `null` values from internal modules
2. Ensures your explicit username and home directory are used
3. Works regardless of evaluation order

```nix
{ config, pkgs, lib, ... }:
{
  home.username = lib.mkForce "alyssaevans";
  home.homeDirectory = lib.mkForce "/Users/alyssaevans";
  home.stateVersion = "24.05";
}
```

### Priority Levels in Nix Module System

Understanding Nix's priority system:

```nix
lib.mkOptionDefault  # Priority 1500 (lowest - can be overridden by anything)
lib.mkDefault        # Priority 1000 (default - can be overridden by explicit values)
# (no modifier)      # Priority 100 (normal/explicit)
lib.mkForce          # Priority 50 (highest - overrides everything else)
```

### Alternative Solutions (Not Recommended)

1. **Set `home.stateVersion = "20.03"`** (version < 20.09)
   - This would enable the old default behavior
   - ❌ Not recommended: Locks you to old behavior and may cause other compatibility issues

2. **Use `lib.mkDefault`** with your values
   - This doesn't work because the `null` value also has default priority
   - ❌ Doesn't solve the conflict

3. **Don't use nix-darwin module, use standalone home-manager**
   - This works but you lose the tight integration benefits
   - ❌ Not ideal: Requires separate activation steps

### When `lib.mkForce` is NOT Needed

You don't need `lib.mkForce` if:
- Using standalone home-manager (not integrated with nix-darwin)
- Using home-manager with nix-darwin but `home.stateVersion < "20.09"`
- Using a version of home-manager before this breaking change was introduced

### Other Important Configuration Notes

#### 1. Trusted Users
```nix
nix.settings.trusted-users = [ "@admin" "alyssaevans" "alyssa" ];
```
Required for:
- Using flakes without sudo
- Building derivations as a regular user
- Proper nix daemon permissions

#### 2. Allow Unfree Packages
```nix
nixpkgs.config.allowUnfree = true;
```
Required for:
- VSCode and many extensions
- Proprietary software packages
- Many development tools

#### 3. State Version
```nix
system.stateVersion = 6;  # darwin
home.stateVersion = "24.05";  # home-manager
```
- Should match when you first installed
- Never arbitrarily change (can break your system)
- Used for backwards compatibility with configuration changes

## Complete Working Example

### File Structure
```
dotfiles/
├── flake.nix
├── darwin/
│   ├── configuration.nix       # Base nix-darwin config
│   └── profiles/
│       ├── alyssa.nix          # Personal machine
│       └── ditto.nix           # Work machine
└── home-manager/
    ├── modules/
    │   └── common.nix          # Shared home-manager config
    └── profiles/
        ├── home.nix            # Personal profile (user: alyssa)
        ├── work.nix            # Work profile (user: alyssaevans)
        ├── code.nix            # Dev profile (user: code)
        └── dev.nix             # Container profile (user: root)
```

### flake.nix
```nix
{
  outputs = { self, nixpkgs, darwin, home-manager, ... }:
    let
      mkDarwin = system: darwinProfile: homeProfile:
        let
          username = if darwinProfile == "alyssa" then "alyssa" else "alyssaevans";
        in
        darwin.lib.darwinSystem {
          inherit system;
          modules = [
            ./darwin/configuration.nix
            ./darwin/profiles/${darwinProfile}.nix

            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${username} = {
                imports = [
                  ./home-manager/modules/common.nix
                  ./home-manager/profiles/${homeProfile}.nix
                ];
              };
            }
          ];
        };
    in
    {
      darwinConfigurations = {
        "alyssa" = mkDarwin "aarch64-darwin" "alyssa" "home";
        "ditto" = mkDarwin "aarch64-darwin" "ditto" "work";
      };
    };
}
```

### home-manager/profiles/work.nix
```nix
# Work profile for user 'alyssaevans'
{ config, pkgs, lib, ... }:
{
  # CRITICAL: lib.mkForce is required when using home-manager
  # as a nix-darwin module with stateVersion >= "20.09"
  # See docs/nix-darwin-home-manager-setup.md for detailed explanation
  home.username = lib.mkForce "alyssaevans";
  home.homeDirectory = lib.mkForce "/Users/alyssaevans";
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    teleport
    cmake
    openjdk
  ];
}
```

## Troubleshooting

### Error: "Home directory could not be determined"
**Solution:** Add `lib.mkForce` to both `home.username` and `home.homeDirectory`

### Error: "Username could not be determined"
**Solution:** Same as above - use `lib.mkForce`

### Build works the first time but fails on rebuild
**Cause:** Flake lock file updated, pulling in newer home-manager with the breaking change
**Solution:** Ensure all profiles use `lib.mkForce` consistently

### Permission denied errors with flakes
**Solution:** Add your user to `nix.settings.trusted-users`

## References

- [Home-Manager Issue #1698](https://github.com/nix-community/home-manager/issues/1698) - Discussion about this breaking change
- [Nix Module System Priority](https://nixos.org/manual/nixos/stable/#sec-option-definitions-setting-priorities)
- [Home-Manager Manual - nix-darwin module](https://nix-community.github.io/home-manager/index.xhtml#sec-install-nix-darwin-module)

## Version Info

This guide was written based on:
- nix-darwin: latest (2025-12)
- home-manager: latest (2025-12-30)
- nixpkgs: nixos-unstable (2025-12)
- Nix: 2.18+ (with flakes enabled)
