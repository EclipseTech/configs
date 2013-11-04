# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
    fi
fi

if [ -e /usr/share/terminfo/x/xterm-256color ]; then
        export TERM='xterm-256color'
else
        export TERM='xterm-color'
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
export M2_HOME=$(readlink -f /usr/bin/mvn | sed "s:bin/mvn::")
export M2=$(readlink -f /usr/bin/mvn | sed "s:mvn::")
export MAVEN_OPTS="-Xmx4096m -XX:MaxPermSize=4096m"
export ANT_HOME=$(readlink -f /usr/bin/ant | sed "s:bin/ant::")
export ANT_OPTS="-Xmx512m -XX:MaxPermSize=512m -Dhttp.proxyHost=http://proxy.website.com -Dhttp.proxyPort=8080"
export XMLLINT_INDENT='    '

set -o vi

#http_proxy=http://proxy.website.com:8080
#https_proxy=http://proxy.website.com:8080
#ftp_proxy=http://proxy.website.com:8080
#no_proxy="localhost,127.0.0.1"
#export http_proxy
#export https_proxy
#export ftp_proxy
#export no_proxy

