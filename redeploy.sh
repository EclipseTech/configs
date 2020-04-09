#!/bin/bash -ex

# wget this script from github

DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ "$DISTRO" == '"Ubuntu"' ]]; then
    # Debian
    sudo apt-get update
    sudo apt-get install -y zsh zsh-doc dos2unix curl inotify-tools
    # TODO change to python git-up and stop installing ruby
    #sudo gem install git-up
elif [[ "$DISTRO" == '"CentOS Linux"' ]]; then
    sudo yum install -y zsh
fi

set +x
mkdir -p ~/bin
ln -s ~/configs/bin/* ~/bin
ln -s ~/configs/.gitconfig ~/
ln -s ~/configs/.vimrc ~/
ln -s ~/configs/.screenrc ~/
ln -s ~/configs/.zshrc ~/
ln -s ~/configs/.zshenv ~/
set -x

chsh -s /bin/zsh
exec zsh

# install vim plugins
vim '+exit'
