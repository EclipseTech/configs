# wt - switch between git worktrees, for bash and zsh.
#
# Install: source this file from ~/.bashrc and/or ~/.zshrc
#   source ~/bin/wt.sh
#
# zsh completion additionally needs the completion system loaded first:
#   autoload -Uz compinit && compinit
#
# Usage:
#   wt                       pick a worktree (fzf if installed, else a numbered menu)
#   wt <name>                cd to a worktree by directory name or branch name
#   wt -i, --interactive     pick a worktree (fzf if installed, else a numbered menu)
#   wt -l, --list, ls        list worktrees
#   wt -                     cd to the main worktree
#   wt -c, --create <branch> [path]
#                            create a worktree for <branch> and cd into it
#   wt repair [<path>...]    fix worktree pointers after something was moved
#   wt move | mv [<name>] [<dest>]
#                            move a worktree (updates git's pointers properly);
#                            a <dest> without '/' renames it in place
#   wt rm | remove [-f] [-b] [<name>]
#                            remove a worktree (-f force, -b also delete branch)
#   wt -h, --help            this message
#
# Optional: fzf (https://github.com/junegunn/fzf) for the interactive picker.
#
# Config: ~/.worktree, parsed (never sourced), one key=value per line:
#   worktree_base="~/workspace/worktree"
# New worktrees are created at  <worktree_base>/<repo>/<branch-with-slashes-as-dashes>
# $WT_BASE overrides the config file. With neither set, new worktrees are
# created beside the main worktree.

# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

# Expand a leading ~ (we never eval config values).
_wt_expand_tilde() {
  case "$1" in
    '~') printf '%s\n' "$HOME" ;;
    '~/'*) printf '%s\n' "$HOME/${1#\~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Read one key from ~/.worktree. Strict parse, no eval, no source.
_wt_config_get() {
  _wtc_key="$1"; _wtc_line=; _wtc_k=; _wtc_v=; _wtc_out=
  [ -r "$HOME/.worktree" ] || return 0
  while IFS= read -r _wtc_line || [ -n "$_wtc_line" ]; do
    case "$_wtc_line" in
      '#'*|'') continue ;;
      *=*) ;;
      *) continue ;;
    esac
    _wtc_k=${_wtc_line%%=*}
    _wtc_v=${_wtc_line#*=}
    _wtc_k=${_wtc_k#"${_wtc_k%%[![:space:]]*}"}; _wtc_k=${_wtc_k%"${_wtc_k##*[![:space:]]}"}
    _wtc_v=${_wtc_v#"${_wtc_v%%[![:space:]]*}"}; _wtc_v=${_wtc_v%"${_wtc_v##*[![:space:]]}"}
    case "$_wtc_v" in
      '"'*'"') _wtc_v=${_wtc_v#\"}; _wtc_v=${_wtc_v%\"} ;;
      "'"*"'") _wtc_v=${_wtc_v#\'}; _wtc_v=${_wtc_v%\'} ;;
    esac
    [ "$_wtc_k" = "$_wtc_key" ] && _wtc_out=$_wtc_v
  done < "$HOME/.worktree"
  [ -n "$_wtc_out" ] && printf '%s\n' "$_wtc_out"
  return 0
}

# Base directory for new worktrees, or empty if unconfigured.
_wt_base_dir() {
  _wtb=${WT_BASE:-}
  [ -z "$_wtb" ] && _wtb=$(_wt_config_get worktree_base)
  [ -z "$_wtb" ] && return 0
  _wtb=$(_wt_expand_tilde "$_wtb")
  printf '%s\n' "${_wtb%/}"
}

# Emit "<path>\t<branch>" for every worktree, main worktree first.
_wt_list() {
  _wtl_path=; _wtl_branch=; _wtl_line=
  command git worktree list --porcelain 2>/dev/null | {
    while IFS= read -r _wtl_line || [ -n "$_wtl_line" ]; do
      case "$_wtl_line" in
        'worktree '*)
          [ -n "$_wtl_path" ] && printf '%s\t%s\n' "$_wtl_path" "${_wtl_branch:-(detached)}"
          _wtl_path=${_wtl_line#worktree }
          _wtl_branch=
          ;;
        'branch '*)
          _wtl_branch=${_wtl_line#branch }
          _wtl_branch=${_wtl_branch#refs/heads/}
          ;;
        'detached') _wtl_branch='(detached)' ;;
        'bare')     _wtl_branch='(bare)' ;;
      esac
    done
    [ -n "$_wtl_path" ] && printf '%s\t%s\n' "$_wtl_path" "${_wtl_branch:-(detached)}"
  }
  return 0
}

# Absolute path of the main worktree (the first record).
_wt_main() {
  _wt_list | head -n 1 | cut -f1
}

# Canonical destination for a branch: <base>/<repo>/<slug>, or beside main.
_wt_dest_for_branch() {
  _wtd_branch="$1"
  _wtd_base=$(_wt_base_dir)
  _wtd_main=$(_wt_main)
  _wtd_repo=${_wtd_main##*/}
  _wtd_slug=$(printf '%s' "$_wtd_branch" | tr '/' '-')
  if [ -n "$_wtd_base" ]; then
    printf '%s/%s/%s\n' "$_wtd_base" "$_wtd_repo" "$_wtd_slug"
  else
    printf '%s/%s\n' "${_wtd_main%/*}" "$_wtd_slug"
  fi
}

# Worktree entries matching a query: exact dir name, then exact branch,
# then substring on either. One "<path>\t<branch>" line per match.
_wt_resolve() {
  _wtr_q="$1"; _wtr_e=; _wtr_p=; _wtr_b=; _wtr_hits=; _wtr_all=
  _wtr_all=$(_wt_list)
  [ -z "$_wtr_all" ] && return 1

  _wtr_hits=$(printf '%s\n' "$_wtr_all" | while IFS= read -r _wtr_e; do
    _wtr_p=${_wtr_e%%	*}
    [ "${_wtr_p##*/}" = "$_wtr_q" ] && printf '%s\n' "$_wtr_e"
  done)
  if [ -z "$_wtr_hits" ]; then
    _wtr_hits=$(printf '%s\n' "$_wtr_all" | while IFS= read -r _wtr_e; do
      _wtr_p=${_wtr_e%%	*}; _wtr_b=${_wtr_e#*	}
      [ "$_wtr_b" = "$_wtr_q" ] && printf '%s\n' "$_wtr_e"
    done)
  fi
  if [ -z "$_wtr_hits" ]; then
    _wtr_hits=$(printf '%s\n' "$_wtr_all" | while IFS= read -r _wtr_e; do
      _wtr_p=${_wtr_e%%	*}; _wtr_b=${_wtr_e#*	}
      case "${_wtr_p##*/}" in *"$_wtr_q"*) printf '%s\n' "$_wtr_e"; continue ;; esac
      case "$_wtr_b" in *"$_wtr_q"*) printf '%s\n' "$_wtr_e" ;; esac
    done)
  fi
  [ -z "$_wtr_hits" ] && return 1
  printf '%s\n' "$_wtr_hits"
}

# Completion candidates: directory basenames and branch names, one per line.
_wt_names() {
  _wtn_line=; _wtn_p=; _wtn_b=; _wtn_base=
  _wt_list | while IFS= read -r _wtn_line; do
    _wtn_p=${_wtn_line%%	*}
    _wtn_b=${_wtn_line#*	}
    _wtn_base=${_wtn_p##*/}
    printf '%s\n' "$_wtn_base"
    case "$_wtn_b" in
      '(detached)'|'(bare)'|"$_wtn_base"|'') ;;
      *) printf '%s\n' "$_wtn_b" ;;
    esac
  done
}

# Picker. Takes "<path>\t<branch>" lines as $1 and an optional initial query
# as $2, prints the chosen path on stdout. Uses fzf when installed, otherwise
# a numbered menu. The menu and prompt go to stderr so stdout stays clean for
# command substitution, and the answer is read from /dev/tty for the same reason.
# Returns 0 on a pick, 2 if the user cancelled, 1 if we cannot prompt at all.
_wt_pick() {
  _wtp_all=$(printf '%s\n' "$1" | sed '/^[[:space:]]*$/d')
  _wtp_n=0; _wtp_line=; _wtp_p=; _wtp_b=; _wtp_ans=; _wtp_sel=
  [ -z "$_wtp_all" ] && return 1
  # Can we actually prompt? /dev/tty can exist but be unopenable (cron, a
  # detached process), so test by opening it rather than with [ -r ].
  { : < /dev/tty; } 2>/dev/null || return 1

  # fzf draws on /dev/tty itself; a single entry needs no picking.
  case "$_wtp_all" in
    *'
'*)
      if command -v fzf >/dev/null 2>&1; then
        _wtp_sel=$(printf '%s\n' "$_wtp_all" | fzf --delimiter='\t' --with-nth=2,1 \
          --height=40% --reverse --no-multi --query="${2-}") || return 2
        printf '%s\n' "${_wtp_sel%%	*}"
        return 0
      fi
      ;;
  esac

  while IFS= read -r _wtp_line; do
    _wtp_n=$((_wtp_n + 1))
    _wtp_p=${_wtp_line%%	*}; _wtp_b=${_wtp_line#*	}
    if [ "$_wtp_b" = "$_wtp_p" ]; then
      printf '%3d) %s\n' "$_wtp_n" "$_wtp_p" >&2
    else
      printf '%3d) %-28s %s\n' "$_wtp_n" "$_wtp_b" "$_wtp_p" >&2
    fi
  done <<EOF
$_wtp_all
EOF

  [ "$_wtp_n" -eq 0 ] && return 1
  if [ "$_wtp_n" -eq 1 ]; then
    printf '%s\n' "${_wtp_all%%	*}"
    return 0
  fi

  printf 'select [1-%d, q to cancel]: ' "$_wtp_n" >&2
  IFS= read -r _wtp_ans < /dev/tty 2>/dev/null || return 2
  case "$_wtp_ans" in
    ''|q|Q) return 2 ;;
    *[!0-9]*) printf 'wt: not a number: %s\n' "$_wtp_ans" >&2; return 2 ;;
  esac
  if [ "$_wtp_ans" -lt 1 ] || [ "$_wtp_ans" -gt "$_wtp_n" ]; then
    printf 'wt: out of range\n' >&2
    return 2
  fi
  _wtp_sel=$(printf '%s\n' "$_wtp_all" | sed -n "${_wtp_ans}p")
  printf '%s\n' "${_wtp_sel%%	*}"
  return 0
}

# When git refuses to work here, say something more useful than "not a repo".
_wt_diagnose() {
  _wtx_gd=
  if [ -f .git ]; then
    _wtx_gd=$(sed -n 's/^gitdir: *//p' .git 2>/dev/null | head -n 1)
    if [ -n "$_wtx_gd" ] && [ ! -e "$_wtx_gd" ]; then
      printf 'wt: this looks like a worktree whose main repository moved.\n' >&2
      printf '    its .git file points at: %s\n' "$_wtx_gd" >&2
      printf '    fix it by running `wt repair` from the main repository.\n' >&2
      return 0
    fi
  fi
  return 1
}

# --------------------------------------------------------------------------
# wt
# --------------------------------------------------------------------------

wt() {
  [ -n "${ZSH_VERSION-}" ] && emulate -L zsh

  local entries e p b query hits nhits pick main base repo slug dest branch
  local remote found src cur_top out rc force delbranch

  entries=$(_wt_list)
  if [ -z "$entries" ]; then
    _wt_diagnose || printf 'wt: not inside a git repository\n' >&2
    return 1
  fi

  query=
  case "${1-}" in
    -h|--help)
      printf '%s\n' \
        'usage:' \
        '  wt                          pick a worktree interactively' \
        '  wt <name>                   cd by directory name or branch name' \
        '  wt -i, --interactive        pick with fzf, or a numbered menu without it' \
        '  wt -l, --list, ls           list worktrees' \
        '  wt -                        cd to the main worktree' \
        '  wt -c, --create <branch> [path]' \
        '                              create a worktree and cd into it' \
        '  wt repair [<path>...]       fix pointers after a directory was moved' \
        '                              name paths if BOTH the repo and a worktree moved' \
        '  wt move | mv [<name>] [<dest>]' \
        '                              move a worktree, updating git properly;' \
        '                              a <dest> without / renames it in place' \
        '                              no args: relocate current one under the base dir' \
        '  wt rm | remove [-f] [-b] [<name>]' \
        '                              remove a worktree (default: the current one)' \
        '                              -f force (dirty tree), -b also delete its branch' \
        '' \
        'config: ~/.worktree   worktree_base="~/workspace/worktree"' \
        '        $WT_BASE overrides it'
      return 0
      ;;

    -l|--list|list|ls)
      printf '%s\n' "$entries" | while IFS= read -r e; do
        p=${e%%	*}; b=${e#*	}
        printf '%-28s %s\n' "$b" "$p"
      done
      return 0
      ;;

    -)
      main=$(_wt_main)
      [ -n "$main" ] && cd "$main"
      return $?
      ;;

    -i|--interactive)
      pick=$(_wt_pick "$entries"); rc=$?
      case "$rc" in
        0) cd "$pick"; return $? ;;
        2) return 0 ;;
        *) printf 'wt: cannot prompt here (no terminal)\n' >&2; return 1 ;;
      esac
      ;;

    -c|--create)
      shift
      branch="${1-}"
      if [ -z "$branch" ]; then
        printf 'wt: -c needs a branch name\n' >&2
        return 1
      fi
      dest="${2-}"
      if [ -z "$dest" ]; then
        dest=$(_wt_dest_for_branch "$branch")
      else
        dest=$(_wt_expand_tilde "$dest")
      fi
      if [ -e "$dest" ]; then
        printf 'wt: %s already exists\n' "$dest" >&2
        return 1
      fi

      if command git show-ref --verify --quiet "refs/heads/$branch"; then
        command git worktree add "$dest" "$branch" || return $?
      else
        # NB: while-read, not `for r in $(git remote)` - zsh does not
        # word-split unquoted command substitution the way bash does.
        found=
        while IFS= read -r remote; do
          [ -z "$remote" ] && continue
          if [ -z "$found" ] && command git show-ref --verify --quiet "refs/remotes/$remote/$branch"; then
            found=$remote
          fi
        done <<EOF
$(command git remote)
EOF
        if [ -n "$found" ]; then
          command git worktree add --track -b "$branch" "$dest" "$found/$branch" || return $?
        else
          command git worktree add -b "$branch" "$dest" || return $?
        fi
      fi
      cd "$dest"
      return $?
      ;;

    repair)
      shift
      main=$(_wt_main)
      out=
      # Pass 1: from here. Fixes the main repo's back-pointer to this worktree.
      out="$out$(command git worktree repair 2>&1)"
      # Pass 2: from the main worktree, naming every worktree we know about.
      # Fixes each worktree's own .git file, e.g. after the main repo moved.
      # Re-read the list: pass 1 may have just corrected some of these paths.
      # Any extra arguments are worktree paths the user is telling us about,
      # which is how you recover when BOTH the repo and a worktree moved:
      # git no longer knows the new location, so it has to be named.
      main=$(_wt_main)
      while IFS= read -r e; do
        p=${e%%	*}
        [ -z "$p" ] && continue
        [ "$p" = "$main" ] && continue
        [ -d "$p" ] || continue
        set -- "$@" "$p"
      done <<EOF
$(_wt_list)
EOF
      if [ "$#" -gt 0 ]; then
        out="$out
$(cd "$main" && command git worktree repair "$@" 2>&1)"
      fi
      out=$(printf '%s\n' "$out" | sed '/^[[:space:]]*$/d')
      if [ -z "$out" ]; then
        printf 'wt: nothing to repair\n'
      else
        printf '%s\n' "$out"
      fi
      printf '\n'
      wt -l
      return 0
      ;;

    move|mv)
      shift
      cur_top=$(command git rev-parse --show-toplevel 2>/dev/null)
      if [ "$#" -ge 2 ]; then
        src=$(_wt_resolve "$1" | cut -f1)
        if [ -z "$src" ]; then
          printf "wt: no worktree matching '%s'\n" "$1" >&2
          return 1
        fi
        nhits=$(printf '%s\n' "$src" | wc -l | tr -d ' ')
        if [ "$nhits" -ne 1 ]; then
          printf "wt: '%s' is ambiguous:\n" "$1" >&2
          printf '  %s\n' "$src" >&2
          return 1
        fi
        dest=$(_wt_expand_tilde "$2")
      elif [ "$#" -eq 1 ]; then
        src=$cur_top
        dest=$(_wt_expand_tilde "$1")
      else
        src=$cur_top
        branch=$(command git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [ -z "$branch" ] || [ "$branch" = HEAD ]; then
          printf 'wt: detached HEAD has no canonical path, give a destination\n' >&2
          return 1
        fi
        dest=$(_wt_dest_for_branch "$branch")
      fi

      if [ -z "$src" ]; then
        printf 'wt: could not determine which worktree to move\n' >&2
        return 1
      fi
      # A bare name (no '/') renames in place, beside the source worktree.
      # Anything with a '/' is a path, like mv (use ./name for the cwd).
      case "$dest" in
        */*) ;;
        *) dest="${src%/*}/$dest" ;;
      esac
      if [ "$src" = "$dest" ]; then
        printf 'wt: already at %s\n' "$dest"
        return 0
      fi
      if [ -e "$dest" ]; then
        printf 'wt: %s already exists\n' "$dest" >&2
        return 1
      fi

      mkdir -p "${dest%/*}" 2>/dev/null
      command git worktree move "$src" "$dest" || return $?
      printf 'moved %s -> %s\n' "$src" "$dest"
      # follow it only if we were standing in it
      if [ "$src" = "$cur_top" ]; then
        cd "$dest"
      fi
      return $?
      ;;

    rm|remove)
      shift
      force=; delbranch=
      while [ "$#" -gt 0 ]; do
        case "$1" in
          -f|--force)  force=--force ;;
          -b|--branch) delbranch=1 ;;
          --) shift; break ;;
          -*) printf 'wt: unknown option %s for rm\n' "$1" >&2; return 1 ;;
          *) break ;;
        esac
        shift
      done
      main=$(_wt_main)
      cur_top=$(command git rev-parse --show-toplevel 2>/dev/null)
      if [ "$#" -ge 1 ]; then
        src=$(_wt_resolve "$1" | cut -f1)
        if [ -z "$src" ]; then
          printf "wt: no worktree matching '%s'\n" "$1" >&2
          return 1
        fi
        nhits=$(printf '%s\n' "$src" | wc -l | tr -d ' ')
        if [ "$nhits" -ne 1 ]; then
          printf "wt: '%s' is ambiguous:\n" "$1" >&2
          printf '  %s\n' "$src" >&2
          return 1
        fi
      else
        src=$cur_top
      fi

      if [ -z "$src" ]; then
        printf 'wt: could not determine which worktree to remove\n' >&2
        return 1
      fi
      if [ "$src" = "$main" ]; then
        printf 'wt: refusing to remove the main worktree\n' >&2
        return 1
      fi

      branch=$(command git -C "$src" symbolic-ref --short -q HEAD 2>/dev/null)
      # step out of it first if we are standing in it
      if [ "$src" = "$cur_top" ]; then
        cd "$main" || return $?
      fi
      command git -C "$main" worktree remove $force "$src"; rc=$?
      if [ "$rc" -ne 0 ]; then
        [ "$src" = "$cur_top" ] && cd "$src"
        return "$rc"
      fi
      printf 'removed %s\n' "$src"
      if [ -n "$delbranch" ]; then
        if [ -n "$branch" ]; then
          command git -C "$main" branch -d "$branch" || return $?
        else
          printf 'wt: worktree was detached, no branch to delete\n' >&2
        fi
      fi
      return 0
      ;;

    -*)
      printf 'wt: unknown option %s (try wt -h)\n' "${1-}" >&2
      return 1
      ;;

    '')
      pick=$(_wt_pick "$entries"); rc=$?
      case "$rc" in
        0) cd "$pick"; return $? ;;
        2) return 0 ;;
        *) wt -l; return 0 ;;
      esac
      ;;

    *) query="$1" ;;
  esac

  hits=$(_wt_resolve "$query")
  if [ -z "$hits" ]; then
    printf "wt: no worktree matching '%s'\n" "$query" >&2
    return 1
  fi

  nhits=$(printf '%s\n' "$hits" | wc -l | tr -d ' ')
  if [ "$nhits" -eq 1 ]; then
    cd "${hits%%	*}"
    return $?
  fi

  printf "wt: '%s' matches %s worktrees:\n" "$query" "$nhits" >&2
  pick=$(_wt_pick "$hits" "$query"); rc=$?
  case "$rc" in
    0) cd "$pick"; return $? ;;
    2) return 1 ;;
    *) return 1 ;;
  esac
}

# --------------------------------------------------------------------------
# completion
# --------------------------------------------------------------------------

if [ -n "${ZSH_VERSION-}" ]; then
  # Tip: for labelled groups, add to ~/.zshrc:
  #   zstyle ':completion:*:*:wt:*' group-name ''
  #   zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
  _wt() {
    local -a dirs branches
    local e p b base
    for e in ${(f)"$(_wt_list)"}; do
      [[ -z $e ]] && continue
      p=${e%%$'\t'*}; b=${e#*$'\t'}; base=${p:t}
      dirs+=( "${base//:/\\:}:${b}" )
      if [[ -n $b && $b != '(detached)' && $b != '(bare)' && $b != $base ]]; then
        branches+=( "${b//:/\\:}:${p}" )
      fi
    done
    _describe -t worktree-dirs     'worktree' dirs
    _describe -t worktree-branches 'branch'   branches
    # Commands are shown for reference but deliberately NOT completable, so
    # TAB only ever lands on a worktree. compadd -x displays, never inserts.
    # To make them selectable instead, replace this with:
    #   local -a cmds; cmds=( '-i:pick from a menu' '-l:list' ... )
    #   (( CURRENT == 2 )) && _describe -t wt-commands 'command' cmds
    if (( CURRENT == 2 )); then
      compadd -x 'commands (type in full):  -i  -l  -c <branch>  repair  move|mv  rm|remove  -'
    fi
    return 0
  }
  compdef _wt wt 2>/dev/null || true

elif [ -n "${BASH_VERSION-}" ]; then
  # readline has no display-only candidate, so bash completes worktrees only.
  _wt_complete_bash() {
    local cur n
    COMPREPLY=()
    [ "$COMP_CWORD" -eq 1 ] || return 0
    cur="${COMP_WORDS[COMP_CWORD]}"
    while IFS= read -r n; do
      [ -z "$n" ] && continue
      case "$n" in "$cur"*) COMPREPLY+=("$n") ;; esac
    done < <(_wt_names)
    return 0
  }
  complete -F _wt_complete_bash wt
fi
