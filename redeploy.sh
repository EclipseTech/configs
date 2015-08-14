#!/bin/bash -ex

# wget this script from github

# Debian
sudo apt-get update
sudo apt-get install -y zsh zsh-doc git vim ruby ruby-dev make python-pip dos2unix curl inotify-tools
sudo gem install git-up

mkdir ~/.ssh
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

echo "MANUAL: Go to github, add ~/.ssh/id_rsa.pub to ssh keys"
cat ~/.ssh/id_rsa.pub
read -n1 -r -p "Press any key to continue..." key
echo

git clone git@github.com:EclipseTech/configs.git ~/configs

mkdir -p ~/bin
ln -s ~/configs/bin/* ~/bin
ln -s ~/configs/.gitconfig ~/
ln -s ~/configs/.vimrc ~/
ln -s ~/configs/.zshrc ~/
ln -s ~/configs/.zshenv ~/

chsh -s /bin/zsh
exec zsh

# install vim plugins
vim '+exit'

