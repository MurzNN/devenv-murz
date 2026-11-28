# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

alias s="supervisorctl"
alias ss="supervisorctl status"
alias sr="supervisorctl restart"
alias logs="supervisorctl tail"
alias la="ls -la"

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    if [ -f "$rc" ]; then
      source "$rc"
    fi
  done
fi

export HISTFILE="/mnt/user/.bash_history"

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
