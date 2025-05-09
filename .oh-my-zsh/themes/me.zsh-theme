function git_path_relative_to_root() {
  local repo_path
  local relative_path
  if repo_path="$(git_repo_name 2>&1 /dev/null)" && [[ -n "$repo_path" ]]; then
    if relative_path="$(realpath -m --relative-to=$(__git_prompt_git rev-parse --show-toplevel)/.. . 2>/dev/null)" && [[ -n "$relative_path" ]]; then
      echo ${relative_path}
    fi
  else
    basename $(pwd)
  fi
}

PROMPT='%{$fg[green]%}$(git_path_relative_to_root)%{$reset_color%} %(!.#.$) '
unset RPROMPT

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}(%{$fg[blue]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg[blue]%})%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}%1{X%}"
