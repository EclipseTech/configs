#!/bin/bash -ex

# wget this script from github

DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ "$DISTRO" == '"Ubuntu"' ]]; then
    # Debian
    sudo apt-get update
    sudo apt-get install -y zsh zsh-doc dos2unix curl inotify-tools
    curl -LsSf https://astral.sh/uv/install.sh | sh
    uv tool install git-up
elif [[ "$DISTRO" == '"CentOS Linux"' ]]; then
    sudo yum install -y zsh
fi

set +x
mkdir -p ~/bin
ln -s ~/configs/bin/* ~/bin
ln -s ~/configs/.gitconfig ~/
ln -s ~/configs/.vimrc ~/
ln -s ~/configs/.screenrc ~/
set -x

chsh -s $(which zsh)
# Get oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
rm ~/.zshrc
ln -s ~/configs/.zshrc ~/
ln -s ~/configs/.zshenv ~/
ln -s ~/configs/.oh-my-zsh/themes/me.zsh-theme ~/.oh-my-zsh/themes/
ln -s ~/configs/.oh-my-zsh/themes/my.zsh-theme ~/.oh-my-zsh/themes/

# install vim plugins
vim '+exit'

exec zsh

