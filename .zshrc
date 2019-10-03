# vim: expandtab tabstop=4 shiftwidth=4

################################################################
# => Prompt
################################################################
autoload -U promptinit
promptinit
# For valid color values
# run http://www.vim.org/scripts/script.php?script_id=1349
LEFT_COLOR='white'
RIGHT_COLOR='green'
if [ -f ~/.zsh-colors ]; then . ~/.zsh-colors; fi
PS1='%F{$LEFT_COLOR}%n@%m:%(!.#.$) %f'
setopt prompt_subst
RPROMPT='%F{$RIGHT_COLOR}$(git-rprompt)%~%f'
# TODO make normal mode show (normal mode is currently disabled until this can be improved)
#function zle-line-init zle-keymap-select {
    #VIM_PROMPT="%{$fg_bold[yellow]%}[% N]% %{$reset_color%}"
    #PS1="%F{$LEFT_COLOR}%n@%m:${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/}%(!.#.$)%f $EPS1"
    #zle reset-prompt
#}

################################################################
# => Colored output
################################################################
exec 2>>( while read X; do print "\e[91m${X}\e[0m" > /dev/tty; done & )

################################################################
# => Aliases
################################################################
alias ls="ls -F --color=auto"
alias vi="vim"
alias grep="grep --color=auto --exclude-dir=*.git"
alias egrep="egrep --color=auto --exclude-dir=*.git"
alias fgrep="fgrep --color=auto --exclude-dir=*.git"
alias pcregrep="pcregrep --color --exclude-dir=.git"
alias ll="ls -la"
alias la="ls -a"
alias l="ls"
alias sl="ls"
alias tree="tree -F -C"
alias ipython="ipython --no-confirm-exit"
alias gst="git status -u"
alias gb="git branch -vv"
alias gba="git branch -vv -a"
alias sz='exec zsh'
alias ez='vim ~/.zshrc'
alias ev='vim ~/.vimrc'
alias es='vim ~/.screenrc'
function find-large-files() {
    find . -type f -size +10000k -exec ls -lh {} \; | awk '{ print $5 ":	" $9 }' | sort -h
}

################################################################
# => Global Aliases
################################################################
alias -g G="| grep"
alias -g L="| less"
alias -g ...="../.."
alias -g ....="../.."
alias -g ..2="../.."
alias -g ..3="../../.."
alias -g ..4="../../../.."
alias -g ..5="../../../../.."

################################################################
# => Auto Completion
################################################################
# Add local ~/.zsh/completion loading
fpath=(~/.zsh/completion $fpath)
# Enable zsh completion
autoload -Uz compinit
compinit
# ssh hostname completion
# Line required in ~/.ssh/config
#   HashKnownHosts no
zstyle -e ':completion::*:*:*:hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'
# shows documentation if available (ls -<TAB> shows ls option docs)
zstyle ':completion:*' verbose yes
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _force_rehash _complete _ignored
zstyle ':completion:*' insert-unambiguous true
# Colors for all completions
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Case and dash/underscore insensitive, and partial-word matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}' 'l:|=* r:|=*'
zstyle ':completion:*' original true
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
# Tab completion for kill and killall
zstyle ':completion:*:kill:*:processes' command "ps x"
zstyle ':completion:*:killall:*' command 'ps -u $USER -o cmd'
# Don't vi .class files
zstyle ':completion:*:*:vim:*:*files' ignored-patterns '*.class' '*.pyc' '*.pyo'
# Pip completion should be just this...
#if [[ -x $(which pip) ]]; then
#    eval "`pip completion --zsh`"
#fi
# But, inlining it is 200ms faster.
# pip zsh completion start
function _pip_completion {
    local words cword
    read -Ac words
    read -cn cword
    reply=( $( COMP_WORDS="$words[*]" \
        COMP_CWORD=$(( cword-1 )) \
        PIP_AUTO_COMPLETE=1 $words[1] ) )
}
compctl -K _pip_completion pip
# pip zsh completion end
# jenkins-jobs autocompletion
compdef _gnu_generic jenkins-jobs

################################################################
# => Keybinds
################################################################
# vi mode
bindkey -v
# disable vi normal mode on escape
bindkey '^[' beep
# home keybind
bindkey '\e[1~' beginning-of-line
# end keybind
bindkey '\e[4~' end-of-line
case $TERM in (xterm*)
    bindkey '\e[H' beginning-of-line
    bindkey '\e[F' end-of-line ;;
esac
# Home
bindkey OH beginning-of-line
# End
bindkey OF end-of-line
# Page Up
bindkey '[5~' up-line-or-history
# Page Down
bindkey '[6~' down-line-or-history
# Delete key
bindkey '\e[3~' delete-char
# ctrl+leftarrow go back a word
bindkey "[1;5D" vi-backward-word
# ctrl+rightarrow go forward a word
bindkey "[1;5C" vi-forward-word
# ctrl+delete delete word forward from cursor
bindkey '[3;5~' kill-word
bindkey "" history-incremental-search-backward
# ctrl+x+e edit in command line buffer
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^xe' edit-command-line
bindkey '^x^e' edit-command-line
# Get args from previous commands with alt-. and alt-m
autoload -Uz copy-earlier-word
zle -N copy-earlier-word
bindkey '\em' copy-earlier-word
bindkey '\e.' insert-last-word

# Run deactive when in virtualenv on ^D
function deactivate_or_exit() {
    if declare -f deactivate > /dev/null
    then
        deactivate
        echo
        zle reset-prompt
    else
        echo -n "exit" && exit
    fi
}
zle -N deactivate_or_exit

setopt IGNORE_EOF
bindkey '' deactivate_or_exit


################################################################
# => Terminal Title Bar
################################################################
function title() {
    # escape '%' chars in $1, make nonprintables visible
    local a=${(V)1//\%/\%\%}

    # Truncate command, and join lines.
    a=$(print -Pn "%40>...>$a" | tr -d "\n")

    case $TERM in
        screen*)
            print -Pn "\e]2;$a @ $2\a" # plain xterm title
            print -Pn "\ek$a\e\\"      # screen title (in ^A")
            print -Pn "\e_$2   \e\\"   # screen location
            ;;
        xterm*)
            print -Pn "\e]2;$a @ $2\a" # plain xterm title
            ;;
    esac
}

# precmd is called just before the prompt is printed
function precmd() {
    title "zsh" "%m:%55<...<%~"
}

# preexec is called just before any command line is executed
function preexec() {
    title "$1" "%m:%35<...<%~"
}

################################################################
# => General
################################################################
# Max tab completion before asking are you sure question.
LISTMAX=200
# Use zsh-autosuggestions ctrl+space
if [[ -d "/home/$USER/.zsh/zsh-autosuggestions/" ]]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
    export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=50
    bindkey '^ ' autosuggest-accept
fi
# Set timezone
export TZ='America/Denver'
# Turn on unicode support
export LANG="en_US.UTF-8"
# Add ~/git-scripts and ~/bin to path
export PATH=$PATH:~/git-scripts:~/bin
# Add mvn to path
if [[ -d "/usr/local/maven/" ]]; then
    export M2_HOME=/usr/local/maven
    export M2=$M2_HOME/bin
    export PATH=$PATH:$M2
fi
if [[ -d "/usr/bin/java/" ]]; then
    export JAVA_HOME=/usr/bin/java
    export PATH=$PATH:$JAVA_HOME/bin
fi
export PIP_DOWNLOAD_CACHE=~/.pip_download_cache
# Set up dir colors for ls and zsh tab completion
eval $(dircolors -b)
# Share command history between shells
export PROMPT_COMMAND='history -a; $PROMPT_COMMAND'
HISTFILE=~/.histfile
export HISTFILESIZE=100000
export HISTSIZE=100000
export SAVEHIST=100000
setopt APPEND_HISTORY # Don't erase history
setopt EXTENDED_HISTORY # Add additional data to history like timestamp
setopt INC_APPEND_HISTORY # Add immediately
setopt HIST_FIND_NO_DUPS # Don't show duplicates in search
setopt NO_HIST_BEEP # Don't beep
setopt SHARE_HISTORY # Share history between session/terminals
# Set default editor
export EDITOR="vim"
setopt extendedglob
setopt dotglob
# Tab once = list options, again start completing options
setopt automenu
# Don't start completing options until another tab press
unsetopt menucomplete
setopt listpacked
setopt nohup
setopt notify
setopt completeinword
# Type dir name to cd
setopt autocd
setopt interactivecomments
unsetopt bashautolist
setopt autolist
unsetopt listambiguous
setopt autoparamslash
unsetopt nomatch
unsetopt nullglob
# incrementally add items to history
setopt incappendhistory
# ignore consecutive dups in history
setopt histignoredups
setopt autopushd pushdignoredups pushdtohome
# Avoid having to manually run rehash
_force_rehash() {
    (( CURRENT == 1 )) && rehash
    return 1 # Because we didn't really complete anything
}
# Set 256 terminal color if available
if [ -e /usr/share/terminfo/x/xterm-256color ] || [ -e /lib/terminfo/x/xterm-256color ]; then
        export TERM='xterm-256color'
else
        export TERM='xterm'
fi
# Print logged-in-from ip
echo -n "You are: "
who -m
# List directory after cd
function chpwd() { ls }

################################################################
# => Misc and Workarounds
################################################################
# Disable ^s scroll locking
stty -ixon -ixoff -ixany

# Make ^A and ^X increase and decrease the nearest number to left of cursor
_increase_number() {
    local -a match mbegin mend
    [[ $LBUFFER =~ '(-?[0-9]+)[^0-9]*$' ]] &&
    LBUFFER[mbegin,mend]=$(printf %0${#match[1]}d $((10#$match + ${NUMERIC:-1})))
}
_decrease_number() {
    local -a match mbegin mend
    [[ $LBUFFER =~ '(-?[0-9]+)[^0-9]*$' ]] &&
    LBUFFER[mbegin,mend]=$(printf %0${#match[1]}d $((10#$match - ${NUMERIC:-1})))
}
zle -N increase-number _increase_number
zle -N decrease-number _decrease_number
bindkey '^A' increase-number
bindkey '^X' decrease-number

function my-backward-kill-line() {
    # If there is text to the left of the cursor
    if [ -n "$LBUFFER" ]; then
        zle kill-whole-line
    else
        CUTBUFFER=
    fi
    # Always clear the kill ring (talk about a security hole!)
    killring=
}
zle -N my-backward-kill-line
bindkey "^U" my-backward-kill-line
bindkey "^Y" yank
bindkey "^?" backward-delete-char # the default is vi-backward-delete-char, which actually fills the ^y buffer

# Turn on proxy variables
#TODO this doesn't seem to work
function proxy_on() {
    no_proxy="localhost,127.0.0.0/8,::1,localaddress,.localdomain.com"
    echo -n "no proxy: "; read noproxy
    export no_proxy="$no_proxy,$noproxy"
    export NO_PROXY=$no_proxy

    if (( $# > 0 )); then
        valid=$(echo $@ | sed -n 's/\([0-9]\{1,3\}.\)\{4\}:\([0-9]\+\)/&/p')
        if [[ $valid != $@ ]]; then
            >&2 echo "Invalid address"
            return 1
        fi

        export http_proxy="http://$1/"
        export https_proxy=$http_proxy
        export ftp_proxy=$http_proxy
        export rsync_proxy=$http_proxy
        echo "Proxy environment variable set."
        return 0
    fi

    echo -n "username: "; read username
    if [[ $username != "" ]]; then
        echo -n "password: "
        read -es password
        local pre="$username:$password@"
    fi

    echo -n "server: "; read server
    echo -n "port: "; read port
    export http_proxy="http://$pre$server:$port/"
    export https_proxy=$http_proxy
    export ftp_proxy=$http_proxy
    export rsync_proxy=$http_proxy
    export HTTP_PROXY=$http_proxy
    export HTTPS_PROXY=$http_proxy
    export FTP_PROXY=$http_proxy
    export RSYNC_PROXY=$http_proxy
}

# Turn off proxy variables
function proxy_off(){
    unset http_proxy
    unset HTTP_PROXY
    unset https_proxy
    unset HTTPS_PROXY
    unset ftp_proxy
    unset FTP_PROXY
    unset rsync_proxy
    unset RSYNC_PROXY
    echo -e "Proxy environment variable removed."
}

# kubectl kubernetes k8s completion
if [ $commands[kubectl] ]; then source <(kubectl completion zsh); fi
