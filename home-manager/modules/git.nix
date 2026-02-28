{ config, ... }:

{
  # Use a stable path for secrets so git's include.path can reference it directly.
  # The default on macOS is $(getconf DARWIN_USER_TEMP_DIR)/agenix which is a shell
  # expression git cannot evaluate. A path under ~ is stable across sessions.
  age = {
    secretsDir = "${config.home.homeDirectory}/.local/share/agenix";
    identityPaths = [ "${config.home.homeDirectory}/.age/personal-key.txt" ];

    secrets.git-config = {
      file = ../../secrets/personal/git-config.age;
    };
  };

  programs.git = {
    enable = true;
    settings = {
      include.path = "${config.home.homeDirectory}/.local/share/agenix/git-config";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };
}
