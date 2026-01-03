{ config, pkgs, lib, ... }:

{
  options.ditto.swiftDev = {
    enable = lib.mkEnableOption "Ditto Swift SDK development environment";
    
    xcodeVersion = lib.mkOption {
      type = lib.types.str;
      default = "16.2";
      description = "Xcode version to use";
    };
    
    rubyVersion = lib.mkOption {
      type = lib.types.str;
      default = "3.3.0";
      description = "Ruby version for CocoaPods and Jazzy";
    };
  };

  config = lib.mkIf config.ditto.swiftDev.enable {
    homebrew.brews = [
      "xcodes"
      "sourcekitten"
      "clang-format"
      "rbenv"
      "ruby-build"
    ];
    
    environment.variables = {
      XCODE_VERSION = config.ditto.swiftDev.xcodeVersion;
      RUBY_VERSION = config.ditto.swiftDev.rubyVersion;
    };
    
    # Automated Ruby + gems setup (like your puro pattern)
    system.activationScripts.postActivation.text = ''
      # Setup rbenv
      if command -v rbenv &>/dev/null; then
        export PATH="$HOME/.rbenv/shims:$PATH"
        eval "$(rbenv init - zsh)"
        
        # Install Ruby if not present
        if ! rbenv versions | grep -q "${config.ditto.swiftDev.rubyVersion}"; then
          echo "==> Installing Ruby ${config.ditto.swiftDev.rubyVersion}..."
          rbenv install ${config.ditto.swiftDev.rubyVersion}
          rbenv global ${config.ditto.swiftDev.rubyVersion}
        fi
        
        # Install required gems
        export RBENV_VERSION="${config.ditto.swiftDev.rubyVersion}"
        rbenv exec gem list | grep -q cocoapods || rbenv exec gem install cocoapods --no-document
        rbenv exec gem list | grep -q jazzy || rbenv exec gem install jazzy --no-document
        
        echo "✓ Ruby environment ready"
      fi
      
      # Setup Xcode selection if installed
      if [ -d "/Applications/Xcode-${config.ditto.swiftDev.xcodeVersion}.app" ]; then
        sudo xcode-select -s "/Applications/Xcode-${config.ditto.swiftDev.xcodeVersion}.app/Contents/Developer" 2>/dev/null || true
      fi
    '';
  };
}