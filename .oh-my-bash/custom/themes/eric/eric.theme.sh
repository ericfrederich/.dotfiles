#! bash oh-my-bash.module

# Based on zork

export PROMPT_DIRTRIM=4

SCM_THEME_PROMPT_PREFIX=""
SCM_THEME_PROMPT_SUFFIX=""

SCM_THEME_PROMPT_DIRTY=" ${_omb_prompt_bold_brown}✗${_omb_prompt_normal}"
SCM_THEME_PROMPT_CLEAN=" ${_omb_prompt_bold_green}✓${_omb_prompt_normal}"
SCM_GIT_CHAR="${_omb_prompt_bold_green}±${_omb_prompt_normal}"
SCM_SVN_CHAR="${_omb_prompt_bold_teal}⑆${_omb_prompt_normal}"
SCM_HG_CHAR="${_omb_prompt_bold_brown}☿${_omb_prompt_normal}"

# these two copied from cupcake
SCM_GIT_BEHIND_CHAR="${_omb_prompt_brown}↓${_omb_prompt_normal}"
SCM_GIT_AHEAD_CHAR="${_omb_prompt_bold_green}↑${_omb_prompt_normal}"

#Mysql Prompt
export MYSQL_PS1="(\u@\h) [\d]> "

case $TERM in
xterm*)
  TITLEBAR="\[\033]0;\w\007\]"
  ;;
*)
  TITLEBAR=""
  ;;
esac

PS3=">> "

function __my_rvm_ruby_version {
  local gemset=$(awk -F'@' '{print $2}' <<< "$GEM_HOME")
  [[ $gemset ]] && gemset=@$gemset
  local version=$(awk -F'-' '{print $2}' <<< "$MY_RUBY_HOME")
  local full=$version$gemset
  [[ $full ]] && _omb_util_print "[$full]"
}

function is_vim_shell {
  if [[ $VIMRUNTIME ]]; then
    _omb_util_print "[${_omb_prompt_teal}vim shell${_omb_prompt_normal}]"
  fi
}

function modern_scm_prompt {
  local CHAR=$(scm_char)
  if [[ $CHAR == "$SCM_NONE_CHAR" ]]; then
    return
  else
    _omb_util_print "
├─[$(scm_prompt_info)]"
  fi
}

# show chroot if exist
function chroot {
  if [[ $debian_chroot ]]; then
    local my_ps_chroot=$_omb_prompt_bold_teal$debian_chroot$_omb_prompt_normal
    _omb_util_print "($my_ps_chroot)"
  fi
}

# show virtualenvwrapper
function my_ve {
  if [[ $VIRTUAL_ENV ]]; then
    local ve=$(basename "$VIRTUAL_ENV")
    local my_ps_ve=$_omb_prompt_bold_purple$ve$_omb_prompt_normal
    _omb_util_print "($my_ps_ve)"
  fi
  _omb_util_print ""
}

function _omb_theme_PROMPT_COMMAND {
    # This needs to be first to save last command return code
    local RC="$?"

    # Set return status color
    if [[ ${RC} == 0 ]]; then
        ret_status="${_omb_prompt_bold_green}▪${_omb_prompt_normal}"
    else
        ret_status="${_omb_prompt_bold_brown}${RC}💔${_omb_prompt_normal}"
        # ret_status="${_omb_prompt_bold_brown}${RC}💩💔${_omb_prompt_normal}"
    fi


  local my_ps_host="${_omb_prompt_green}\h${_omb_prompt_normal}"
  # yes, these are the the same for now ...
  local my_ps_host_root="${_omb_prompt_green}\h${_omb_prompt_normal}"

  local my_ps_user="${_omb_prompt_bold_green}\u${_omb_prompt_normal}"
  local my_ps_root="${_omb_prompt_bold_brown}\u${_omb_prompt_normal}"

  # nice prompt
  case $(id -u) in
  0) PS1="${TITLEBAR}╭─$(my_ve)$(chroot)[$my_ps_root][$my_ps_host_root]$(__my_rvm_ruby_version)[${_omb_prompt_teal}\w${_omb_prompt_normal}]$(modern_scm_prompt)$(is_vim_shell)
╰─▪ "
     ;;
  *) PS1="${TITLEBAR}╭─$(my_ve)$(chroot)[$my_ps_user][$my_ps_host]$(__my_rvm_ruby_version)[${_omb_prompt_teal}\w${_omb_prompt_normal}]$(modern_scm_prompt)$(is_vim_shell)
╰─${ret_status} "
     ;;
  esac
}

PS2="╰─▪ "

_omb_util_add_prompt_command _omb_theme_PROMPT_COMMAND
