{ config, pkgs, lib, ... }:

{
  options.ditto.swiftDev = {
    enable = lib.mkEnableOption "Ditto Swift SDK development environment";
    
    xcodeVersion = lib.mkOption {
      type = lib.types.str;
      default = "16.2";
      description = "Xcode version to use";
    };
  };

  config = lib.mkIf config.ditto.swiftDev.enable {
    # Homebrew packages for Swift development
    homebrew.brews = [
      "xcodes"           # Xcode version manager
      "sourcekitten"     # Swift API documentation
      "clang-format"     # Objective-C formatting
      "rbenv"            # Ruby version manager
      "ruby-build"       # For installing Ruby versions
    ];
    
    # Environment variables for Swift builds
    environment.variables = {
      XCODE_VERSION = config.ditto.swiftDev.xcodeVersion;
    };
    
    # Activation script (runs on darwin-rebuild)
    system.activationScripts.postActivation.text = ''
      # Ensure xcode-select points to correct Xcode
      if [ -d "/Applications/Xcode-${XCODE_VERSION}.app" ]; then
        sudo xcode-select -s "/Applications/Xcode-${XCODE_VERSION}.app/Contents/Developer"
      fi
    '';
  };
}