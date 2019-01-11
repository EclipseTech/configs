#!/bin/bash -ex

# wget this script from github

DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ "$DISTRO" == '"Ubuntu"' ]]; then
    # Debian
    sudo apt-get update
    sudo apt-get install -y zsh zsh-doc git vim ruby ruby-dev make python-pip dos2unix curl inotify-tools
    # TODO change to python git-up and stop installing ruby
    sudo gem install git-up
elif [[ "$DISTRO" == '"CentOS Linux"' ]]; then
    sudo yum install -y zsh
fi

if [[ ! -d ~/.ssh/ ]]; then
    mkdir ~/.ssh
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

    echo "MANUAL: Go to github, add ~/.ssh/id_rsa.pub to ssh keys"
    cat ~/.ssh/id_rsa.pub
    read -n1 -r -p "Press any key to continue..." key
    echo

    git clone git@github.com:EclipseTech/configs.git ~/configs
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

# setup ~/.ssh/config
if [[ ! -e ~/.ssh/config ]]; then
    cat <<-EOF >> ~/.ssh/config
    HashKnownHosts no

    #https://wiki.gentoo.org/wiki/SSH_jump_host
    Host *+*
        ProxyCommand ssh $(echo %h | sed 's/+[^+]*$//;s/\([^+%%]*\)%%\([^+]*\)$/\2 -l \1/;s/:/ -p /') nc -w1 $(echo %h | sed 's/^.*+//;/:/!s/$/ %p/;s/:/ /')
    EOF
fi


chsh -s /bin/zsh
exec zsh

# install vim plugins
vim '+exit'
