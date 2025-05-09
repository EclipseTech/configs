# vim: expandtab tabstop=2 shiftwidth=2

################################################################
# => oh-my-zsh
################################################################
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="eastwood"
#ZSH_THEME="robbyrussell"
#ZSH_THEME="robbyrussell-mod"
#ZSH_THEME="simple"
ZSH_THEME="my"
#ZSH_THEME="me"

DISABLE_UPDATE_PROMPT=true
DISABLE_AUTO_UPDATE=true

source $ZSH/oh-my-zsh.sh

################################################################
# => General
################################################################
# PATH
export PATH=$PATH:~/bin:~/.local/bin
# Set default editor
export EDITOR="vim"
# Max tab completion before asking are you sure question.
export LISTMAX=200
# Set timezone
export TZ='America/Denver'
# Turn on unicode support
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
# Set open file limit
ulimit -n 8192
# Set up dir colors for ls and zsh tab completion
eval $(dircolors -b)
setopt extendedglob
setopt dotglob
# Get rid of annoying beeps
unsetopt beep
setopt NO_BEEP
#TODO_start go over these options
setopt nohup
setopt notify
setopt autoparamslash
unsetopt nomatch
unsetopt nullglob
setopt autopushd pushdignoredups pushdtohome
#TODO_end
# Set 256 terminal color if available
if [ -e /usr/share/terminfo/x/xterm-256color ] || [ -e /lib/terminfo/x/xterm-256color ]; then
  export TERM='xterm-256color'
else
  export TERM='xterm'
fi
# List directory after cd
function chpwd() { ls }
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
fi

################################################################
# => Aliases
################################################################
alias ls="ls -F --color=auto"
alias vi="vim"
alias b='byobu'
alias tf='terraform'
alias tg='terragrunt'
alias k='kubectl'
alias mk='minikube'
#alias grep="grep --color=auto --exclude-dir=.git --exclude=*.pyc --exclude-dir=.venv --exclude-dir=venv --exclude-dir=venv2 --exclude=*.sql"
alias egrep="egrep --color=auto --exclude-dir=.git --exclude=*.pyc --exclude-dir=venv"
alias fgrep="fgrep --color=auto --exclude-dir=.git --exclude=*.pyc --exclude-dir=venv"
alias pcregrep="pcregrep --color --exclude-dir=.git --exclude=*.pyc --exclude-dir=venv"
# List directory contents
alias ll="ls -la"
alias la="ls -a"
alias l="ls"
alias sl="ls"
alias lsa='ls -lah'
alias tree="tree -F -C"
alias ipython="ipython --no-confirm-exit"
alias gst="git status -u"
alias gb="git branch -vv"
alias gba="git branch -vv -a"
# Switch zsh themes
alias ztheme='(){ export ZSH_THEME="$@" && source $ZSH/oh-my-zsh.sh }'
alias zmy='(){ export ZSH_THEME="my" && source $ZSH/oh-my-zsh.sh }'
alias zme='(){ export ZSH_THEME="me" && source $ZSH/oh-my-zsh.sh }'
# Easy reset zsh
alias sz='exec zsh'
# Easy editing
alias ez='vim ~/.zshrc'
alias ev='vim ~/.vimrc'
alias es='vim ~/.screenrc'
function find-large-files() {
    find . -type f -size +10000k -exec ls -lh {} \; | awk '{ print $5 ":⇒---" $9 }' | sort -h
}
function jwt-decode() {
  sed 's/\./\n/g' <<< $(cut -d. -f1,2 <<< $1) | base64 --decode | jq
}

################################################################
# => Global Aliases
################################################################
alias -g G="| grep"
alias -g L="| less"
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'
alias -g ..2="../.."
alias -g ..3="../../.."
alias -g ..4="../../../.."
alias -g ..5="../../../../.."

################################################################
# => History
################################################################
export HISTFILE=~/.histfile
export HISTSIZE=100000
export SAVEHIST="$HISTSIZE"
setopt APPEND_HISTORY         # Don't erase history
setopt INC_APPEND_HISTORY     # Add immediately
setopt EXTENDED_HISTORY       # Add additional data to history like timestamp
setopt HIST_FIND_NO_DUPS      # Don't show duplicates in search
setopt NO_HIST_BEEP           # Don't beep
setopt SHARE_HISTORY          # Share history between session/terminals
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space

# Page Up - Start typing + Page-Up - fuzzy find history forward
autoload -U up-line-or-beginning-search
zle -N up-line-or-beginning-search
if [[ -n "${terminfo[kpp]}" ]]; then
  bindkey "${terminfo[kpp]}" history-beginning-search-backward
else
  bindkey "[5~" history-beginning-search-backward
fi
# Page Down - Start typing + Page-Down - fuzzy find history backward
autoload -U down-line-or-beginning-search
zle -N down-line-or-beginning-search
if [[ -n "${terminfo[knp]}" ]]; then
  bindkey "${terminfo[knp]}" history-beginning-search-forward
else
  bindkey "[6~" history-beginning-search-forward
fi

################################################################
# => Completions
################################################################
# Add local ~/.zsh/completion loading
fpath=(~/.zsh/completion $fpath)
# Enable zsh completion
autoload -Uz compinit; compinit

# Tab once = list options, again start completing options
setopt automenu
setopt auto_menu
# Don't start completing options until another tab press
unsetopt menucomplete
unsetopt menu_complete
# Automatically list choices on an ambiguous completion
setopt autolist
unsetopt bashautolist
unsetopt listambiguous
# Complete from cursor
setopt completeinword
# Smaller completions list
setopt listpacked

# Shift+Tab - move through the completion menu backwards
if [[ -n "${terminfo[kcbt]}" ]]; then
  bindkey "${terminfo[kcbt]}" reverse-menu-complete
fi

# zstyles
zstyle :compinstall filename '~/.zshrc'
# shows documentation if available (ls -<TAB> shows ls option docs)
zstyle ':completion:*' verbose yes
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' insert-unambiguous true
# Colors for all completions
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Case and dash/underscore insensitive, and partial-word matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}' 'l:|=* r:|=*'
zstyle ':completion:*' original true
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
# Don't autocomplete editor certain file extensions
zstyle ':completion:*:*:vim:*:*files' ignored-patterns '*.class' '*.pyc' '*.pyo'
# Change // to /
zstyle ':completion:*' squeeze-slashes true

# automatically load bash completion functions
autoload -U +X bashcompinit && bashcompinit

if [ $commands[kubectl] ]; then source <(kubectl completion zsh); fi
if [ $commands[helm] ]; then source <(helm completion zsh); fi

################################################################
# => Keybinds
################################################################
# vi mode
bindkey -v
# disable vi normal mode on escape
bindkey '^[' beep
# Home key
bindkey '\e[H' beginning-of-line
if [[ -n "${terminfo[khome]}" ]]; then
  bindkey "${terminfo[khome]}" beginning-of-line
fi
# End key
bindkey '\e[F' end-of-line
if [[ -n "${terminfo[kend]}" ]]; then
  bindkey "${terminfo[kend]}"  end-of-line
fi
# Delete key
if [[ -n "${terminfo[kdch1]}" ]]; then
  bindkey "${terminfo[kdch1]}" delete-char
else
  bindkey '\e[3~' delete-char
  bindkey '^[[3~' delete-char
  bindkey '^[3;5~' delete-char
fi
# ctrl+left-arrow go back a word
bindkey "[1;5D" vi-backward-word
# ctrl+right-arrow go forward a word
bindkey "[1;5C" vi-forward-word
# [Ctrl-r] - Search backward incrementally for a specified string. The string may begin with ^ to anchor the search to the beginning of the line.
bindkey '^r' history-incremental-search-backward
bindkey '^R' history-incremental-search-backward

# Run deactive when in virtualenv on ^D
function deactivate_or_exit() {
  if declare -f deactivate > /dev/null
  then
    deactivate
    echo
    zle reset-prompt
  # pyenv virtualenv
  elif [ ! -z "${VIRTUAL_ENV}" ]; then
    pyenv deactivate
    echo
    zle reset-prompt
  else
    echo -n "exit" && exit
  fi
}
zle -N deactivate_or_exit
bindkey '^D' deactivate_or_exit

