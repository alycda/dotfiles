## Swift

# 1. Rebuild nix-darwin (installs xcodes, rbenv, etc.)
just darwin-rebuild  # or: darwin-rebuild switch --flake .#ditto

# 2. Run Xcode automation (one-time, requires Apple ID)
./scripts/setup-xcode.sh

# 3. Setup Ruby gems
eval "$(rbenv init - zsh)"
rbenv install 3.3.0
rbenv global 3.3.0
gem install cocoapods jazzy

# 4. Clone and build Ditto
gh repo clone getditto/ditto ~/code/ditto
cd ~/code/ditto
make build-ios-simulator
make build-swift