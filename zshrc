# MIT License
#
# Copyright (c) 2022 André Kugland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software
# and associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# [ WHO AM I? ]---------------------------------------------------------------------------------- #
# Let's do this early, before other files are opened. This rather strange workaround assumes that
# zsh will keep this script open while it executes.
() {
  setopt local_options null_glob extended_glob
  for f ( /proc/$$/fd/*(#q-r.) ) {
    [[ ! -f $f ]] && continue
    # The string on the next line is just a meaningless random string.
    if ( grep -qF 5ozBNfkD3fOikjzL9XdeWVzJT9dt626K $f ) {
      _myzshrc_script=${f:A}
      break
    }
  }
}
# ----------------------------------------------------------------------------------------------- #


# [ LOAD FUNCTIONS AND MODULES ]----------------------------------------------------------------- #
zmodload zsh/parameter
zmodload -F zsh/stat b:zstat
# ----------------------------------------------------------------------------------------------- #


# [ DETECT TERMUX ]------------------------------------------------------------------------------ #
[[ $OSTYPE = linux-android && -n $TERMUX_VERSION && -d /data/data/com.termux/files/usr ]]
_myzshrc_termux=$((! ?))                            # Set to 1 if running under Termux.


# [ SOME SANE DEFAULTS ]------------------------------------------------------------------------- #
export EDITOR=${EDITOR:-${commands[nano]}}          # Some default programs
export VISUAL=${VISUAL:-$EDITOR}
export PAGER=${PAGER:=${commands[less]}}
export GPG_TTY=$TTY                                 # Set the TTY for GPG pinentry.

# Paths ----------------------------------------------------------------------------------------- #
() {
  typeset -gxUT PATH path ':'
  typeset -gxUT LD_LIBRARY_PATH ld_library_path ':'
  typeset -U fpath manpath

  [[ -n $__ETC_PROFILE_NIX_SOURCED || -e /etc/NIXOS ]] && return    # Skip if running under Nix.

  append_path() {
    local var=$1
    local dir
    shift
    for dir ($@) {
      [[ ! -e $dir || -h $dir ]] && continue        # Skip if it doesn't exist or it is a symlink.
      if (( ! _myzshrc_termux )) {                  # The following checks fail under Termux.
        (($(zstat +mode $dir) != 16877)) && continue # Skip if mode is not 40775.
        (($(zstat +uid $dir) != 0)) && continue     # Skip if owner is not root.
        (($(zstat +gid $dir) != 0)) && continue     # Skip if group is not root.
      }
      eval ${var}+='( $dir )'                       # Add directory to the path.
    }
  }

  path=()
  ld_library_path=()

  append_path path /{usr/{local/,},}{s,}bin
  append_path path /usr/{,local/}games
  append_path path /snap/bin
  append_path ld_library_path /{usr/{local/,},}lib{,64,32}
  append_path ld_library_path /usr/lib/jvm/default/lib/server
  if (( _myzshrc_termux )) {
    append_path path /data/data/com.termux/files/usr/bin
    append_path ld_library_path /data/data/com.termux/files/usr/lib
    append_path ld_library_path /system/lib64
  }
}

# Dynamic linker -------------------------------------------------------------------------------- #
typeset -gxr LD_PRELOAD=''                          # Disable LD_PRELOAD.
typeset -gtx LD_AUDIT=''                            # Disable LD_AUDIT.
typeset -gtx LD_DYNAMIC_WEAK=0                      # Do not allow weak symbols to be overridden.
typeset -gtx LD_POINTER_GUARD=1                     # Enable pointer guard.
# ----------------------------------------------------------------------------------------------- #


# [ LOAD SCRIPTS FROM /ETC/PROFILE.D ]----------------------------------------------------------- #
if [[ -o login ]] {
  append_path() {                                     # Append a path to the PATH variable.
    emulate -L zsh                                    # This function will be available for scripts
    path+=($1)                                        # in /etc/profile.d.
  }
  setopt null_glob
  for script (/etc/profile{,.d/*.sh}) {
    emulate bash -c "source $script"                  # Source script using bash emulation.
  }
  setopt no_null_glob
  unset script
  unset -f append_path
}
# ----------------------------------------------------------------------------------------------- #


# [ EXIT IF NON-INTERACTIVE SHELL ]-------------------------------------------------------------- #
[[ $- = *i* ]] || return
# ----------------------------------------------------------------------------------------------- #


# ----------------------------------------------------------------------------------------------- #
#                                   START OF INTERACTIVE SECTION
# ----------------------------------------------------------------------------------------------- #

# [ LOAD PLUGINS (FIRST PART) ]------------------------------------------------------------------ #
# First we need to load zsh-defer. Later we'll load the rest of the plugins.

# Check for dependency and install it if missing.
# Parameters:
#   $1: name
#   $2: url of the tarball
_myzshrc_dependency() {
  local name=$1
  local tarball_url=$2
  local version=${${$(print -n $tarball_url | sha256sum)[1]}[1,16]}
  local pkgid=$name-$version
  local error=0

  [[ -d ~/.zshrc-deps ]] || mkdir ~/.zshrc-deps || return 1
  if [[ ! -d ~/.zshrc-deps/$pkgid ]] {
    {
      print -Pnr $'%B%F{243}[%b%fzshrc%B%F{243}]%b%f %F{green}Installing dependency \e[0;4m'"$name"$'\e[0m ... '
      2>/dev/null curl -sSL -o ~/.zshrc-deps/${pkgid}.tar.gz $tarball_url || {
        error=1
        return
      }
      tar --transform "s,^[^/]*,$pkgid,g" -xzf ~/.zshrc-deps/${pkgid}.tar.gz -C ~/.zshrc-deps || {
        error=1
        return
      }
      rm ~/.zshrc-deps/${pkgid}.tar.gz
      ln -s $pkgid ~/.zshrc-deps/$name || {
        error=1
        return
      }
    } always {
      if (( error )) {
        print -P '%B%F{red}failed%b%f'
      } else {
        print -P '%B%F{green}OK%b%f'
      }
    }
  }
}

# zsh defer ------------------------------------------------------------------------------------- #
# renovate: datasource=git-refs depName=https://github.com/romkatv/zsh-defer branch=master
ZSH_DEFER_DIGEST=53a26e287fbbe2dcebb3aa1801546c6de32416fa

_myzshrc_dependency \
  zsh-defer \
  https://github.com/romkatv/zsh-defer/tarball/${ZSH_DEFER_DIGEST} \
  && source ~/.zshrc-deps/zsh-defer/zsh-defer.plugin.zsh
# ----------------------------------------------------------------------------------------------- #


# [ LOAD FUNCTIONS AND MODULES FOR INTERACTIVE SHELLS ]------------------------------------------ #
zmodload zsh/complist zsh/terminfo zsh/zutil zsh/zle
zmodload -m -F zsh/files b:zf_mkdir
autoload -Uz add-zsh-hook compinit is-at-least
# ----------------------------------------------------------------------------------------------- #


# [ SET TMP DIRECTORY ]-------------------------------------------------------------------------- #
if ((!_myzshrc_termux)) {
  _myzshrc_tmp=$TMPPREFIX-$UID
} else {
  _myzshrc_tmp=$HOME/.zshrc-tmp
}

# [ SET SHELL OPTIONS ]-------------------------------------------------------------------------- #
export IFS=$' \t\n\x00'                             # Set IFS to space, tab, newline and null.
setopt interactive_comments                         # Enable comments in interactive shells.
setopt no_beep                                      # Disable beep on errors.
setopt no_correct                                   # Damn you, autocorrect!
[[ $TERM != linux ]] && setopt combining_chars      # Assume the terminal supports combining chars.
                                                    # There are other terminals that don't support
                                                    # combining chars, but I don't use them.

# Expansion ------------------------------------------------------------------------------------- #
setopt extended_glob                                # Extended glob options
setopt no_null_glob                                 # Error when glob doesn't match anything

# Prompt options -------------------------------------------------------------------------------- #
setopt no_prompt_bang                               # Disable Zsh ! in prompt expansion.
setopt prompt_percent                               # Enable Zsh % sequences in prompt expansion.
setopt prompt_subst                                 # Enable Zsh prompt substitution.
setopt transient_rprompt                            # Erase rprompt when accepting a command line.

# Completion options ---------------------------------------------------------------------------- #
setopt auto_param_slash                             # Add a trailing slash to directory names.
setopt auto_remove_slash                            # Remove that slash when word delimiter typed.
setopt complete_in_word                             # Complete in the middle of a word.
setopt list_types                                   # Show type of items in list with trailing mark.
setopt no_cdable_vars                               # Don't use cdable_vars logic (see docs).
setopt no_list_beep                                 # No beep on an ambiguous completion.

# History options ------------------------------------------------------------------------------- #
setopt append_history                               # Append to history file, don't overwrite it.
setopt extended_history                             # Timestamp and duration in history entries.
setopt hist_ignore_all_dups                         # Don't record duplicate commands in history.
setopt hist_ignore_space                            # Don't record commands starting with a space.
setopt hist_no_functions                            # Don't record functions in history.
setopt hist_reduce_blanks                           # Remove extra spaces from history.
setopt hist_verify                                  # History expansion just loads line.
setopt no_hist_beep                                 # Don't beep when searching history.
setopt share_history                                # Share history between multiple shells.
HISTSIZE=10000                                      # Maximum number of history entries in memory.
SAVEHIST=99999                                      # Number of history entries to save to file.
HISTFILE=$_myzshrc_tmp/history                      # Set history file.
readonly HISTSIZE SAVEHIST HISTFILE                 # Make the variables readonly.
[[ $OSTYPE = linux-* ]] && setopt hist_fcntl_lock   # Use fcntl() to lock the history file.
# ----------------------------------------------------------------------------------------------- #


# [ CREATE DIRECTORY FOR ZSH'S HISTORY AND COMPCACHE ]------------------------------------------- #
2>/dev/null zf_mkdir -m 700 $_myzshrc_tmp $_myzshrc_tmp/zcompcache
# ----------------------------------------------------------------------------------------------- #


# [ COLOR SUPPORT ]------------------------------------------------------------------------------ #
# We'll assume that the terminal supports at least 4-bit colors, so we should detect support for
# 8 and 24-bit color. I believe it's also reasonable to assume that a terminal that supports 24-bit
# color will also support 256-color.
[[ $COLORTERM = (24bit|truecolor) ]]; _myzshrc_color24bit=$(( ! $? ))
((_myzshrc_color24bit)) || [[ $TERM = *256color* ]]; _myzshrc_color8bit=$(( ! $? ))
readonly _myzshrc_color24bit
readonly _myzshrc_color24bit
readonly _myzshrc_color8bit

# If 24-bit color is not supported, and Zsh version is at least 5.7.0, we can use the module
# 'zsh/nearcolor' to approximate 24-bit colors as 8-bit colors. On 4-bit terminals, your mileage
# may vary; on $TERM = linux, for example, the resulting 256-color escapes will result in bright
# white text.
! ((_myzshrc_color24bit)) && is-at-least 5.7.0 $ZSH_VERSION && zmodload zsh/nearcolor 2>/dev/null
# ----------------------------------------------------------------------------------------------- #


# [ DETECT SSH SESSIONS ]------------------------------------------------------------------------ #
# First try the easy way: if SSH_CONNECTION is set, we're running under SSH.
_myzshrc_ssh_session=${${SSH_CONNECTION:+1}:-0}

# If SSH_CONNECTION is not set, then we might be running under sudo, so we check whether we have
# sshd as an ancestor process. This will fail for non-root users if /proc was mounted with
# hidepid=2.
if ! ((_myzshrc_ssh_session)) {
  () {
    local IFS=' '                                   # This is needed to split /proc/<pid>/stat.
    local pid=$$                                    # The current process ID.
    local exe                                       # Basename of the executable.
    while ((pid > 1)) {                             # Continue until we reach the init process.
      test -d /proc/$pid || break                   # Give up if the directory doesn't exist.
      pid=${${=${"${:-$(</proc/$pid/stat)}"/*) /}}[2]} # Get the parent process ID.
      exe=${${:-/proc/$pid/exe}:A:t}                # Get the basename of its executable.
      [[ $exe = exe ]] && return 1                  # Path canonicalization fail, return false.
      [[ $exe = sshd ]] && return 0                 # sshd process is our ancestor, return true.
    }
    return 1
  } && _myzshrc_ssh_session=1
}
readonly _myzshrc_ssh_session
# ----------------------------------------------------------------------------------------------- #


# [ DETECT PUTTY ]------------------------------------------------------------------------------- #
# Detect if we're running under PuTTY.
[[ $TERM = putty* || ${PUTTY:-0} -eq 1 ]]; _myzshrc_putty=$(( ! $? ))
# ----------------------------------------------------------------------------------------------- #


# [ DETECT FSTYPE OF $PWD ]---------------------------------------------------------------------- #
# Cache directory filesystem types.
typeset -gA _myzshrc_fstypecache
_myzshrc_fstypecache_hash=""

# Get current directory filesystem type.
# Value is returned in variable REPLY.
_myzshrc_fstypecache_get() {
  local current_hash=${$(sha256sum /proc/self/mounts)[1]} # Hash the contents of mounts file.
  if [[ $current_hash != $_myzshrc_fstypecache_hash ]] { # If the hash has changed,
    _myzshrc_fstypecache_hash=$current_hash         # Reset the cache.
    _myzshrc_fstypecache=( )
  }
  if ! (( ${+_myzshrc_fstypecache[$PWD]} )) {       # If value if not found for $PWD, compute it.
    local fstype=$(findmnt -fn -d backward -o FSTYPE --target $PWD)
    if [[ $fstype = fuse ]] {                   # If the filesystem is FUSE-based,
      local source=$(findmnt -fn -d backward -o SOURCE --target $PWD)
      if [[ $source =~ '.*[#].*' ]] {             # If the source contains a hash,
        fstype=fuse.${source//[#]*}               # Use the part after the hash as the fstype.
      }
    }
    _myzshrc_fstypecache[$PWD]=$fstype            # Cache the value.
  }
  REPLY=${_myzshrc_fstypecache[$PWD]}
}
# ----------------------------------------------------------------------------------------------- #


# [ SEQUENCE TO RESET TERMINAL ]----------------------------------------------------------------- #
_myzshrc_reset_terminal() {
  stty sane -imaxbel -brkint ixoff iutf8            # Reset terminal settings.
  print -nr $'\e<'                                  # Exit VT52 mode.
  print -nr $'\e7\e[?1049l\e8'                      # Use main screen buffer.
  print -nr $'\e7\e[0;0r\e8'                        # DECSTBM: unset top/bottom margins.
  print -nr $'\e(B\e)B'                             # SCS: set G0 and G1 charsets to US-ASCII.
  if ((!_myzshrc_termux)) {
    [[ $TERM != linux ]] && print -nr $'\e*A\e+A'   # SCS: set G2 and G3 charsets to Latin-1.
    print -nr $'\e%G'                               # Enable UTF-8 mode.
  }
  print -nr $'\Co'                                  # Invoke G0 charset as GL
  print -nr $'\e~'                                  # Invoke G1 charset as GR.
  print -nr $'\e#5'                                 # DECSWL: single-width line.
  print -nr $'\e[3l'                                # DECCRM: don't show control characters.
  print -nr $'\e[20l'                               # LNM: disable automatic new lines.
  print -nr $'\e[?5l'                               # DECSCNM: disable reverse video.
  print -nr $'\e7\e[?6l\e8'                         # DECOM: disable origin mode.
  print -nr $'\e[?7h'                               # DECAWM: enable auto-wrap mode.
  print -nr $'\e[?8h'                               # DECARM: enable auto-repeat keys.
  print -nr $'\e[?25h'                              # DECTCEM: make cursor visible.
  print -nr $'\e[?2004h'                            # Enable bracketed paste.
  local s
  for s ($'\e[?'{9,100{0..6},101{5,6}}'l') {
    print -nr $s                                    # Disable xterm mouse and focus events.
  }
  print -nr ${terminfo[smkx]}                       # DECCKM & DECKPAM: use application mode.
  if [[ $TERM = linux ]] {                          # Color palette for Linux virtual console.
    local idx rgb
    for idx rgb (
      0 181716  1 c74f49  2 51c236  3 c4903b        # Black, red, green, yellow
      4 648ecf  5 b475ca  6 3bc4bf  7 ccc8c4        # Blue, magenta, cyan, white
      8 83827b  9 ff7068  a 7fff57  b ffbf57        # Bri black, bri red, bri green, bri yellow
      c 7db7ff  d df91f4  e 57fffc  f ffffff        # Bri blue, bri magenta, bri cyan, bri white
    ) print -nr -- $'\e]P'"${idx}${rgb}"$'\e\\'
  }
}
# ----------------------------------------------------------------------------------------------- #


# [ LOAD LS COLORS ]----------------------------------------------------------------------------- #
# Load colors for LS_COLORS from the appendix of the .zshrc file.
_myzshrc_load_ls_colors() {
  eval $(dircolors -b <(sed -ne '/.*DIR_COLORS_APPENDIX$/,//{s///g;p};' $_myzshrc_script))
  unset -f _myzshrc_load_ls_colors
}
zsh-defer _myzshrc_load_ls_colors
# ----------------------------------------------------------------------------------------------- #


# [ SETUP KEYMAP ]------------------------------------------------------------------------------- #
# Only keys used in this script should be listed here.
typeset -A _myzshrc_keys
_myzshrc_keys=(
  Tab             "${terminfo[ht]}"
  Backspace       "${terminfo[kbs]} ^?"
  Insert          "${terminfo[kich1]}"
  Delete          "${terminfo[kdch1]} ${terminfo[kDC]}"
  Home            "${terminfo[khome]} ${terminfo[kHOM]}"
  End             "${terminfo[kend]}  ${terminfo[kEND]}"
  PageUp          "${terminfo[kpp]}   ${terminfo[kPRV]}"
  PageDown        "${terminfo[knp]}   ${terminfo[kNXT]}"
  ArrowUp         "${terminfo[kcuu1]} ${terminfo[kUP]}"
  ArrowDown       "${terminfo[kcud1]} ${terminfo[kDN]}"
  ArrowRight      "${terminfo[kcuf1]} ${terminfo[kRIT]}"
  ArrowLeft       "${terminfo[kcub1]} ${terminfo[kLFT]}"
  CtrlBackspace   "^H"
  CtrlDelete      "${terminfo[kDC5]} ^[[3;5~"
  CtrlPageUp      "${terminfo[kPRV5]} ^[[5;5~"
  CtrlPageDown    "${terminfo[kNXT5]} ^[[6;5~"
  CtrlRightArrow  "${terminfo[kRIT5]} ^[[1;5C"
  CtrlLeftArrow   "${terminfo[kLFT5]} ^[[1;5D"
)

# Workarounds for problematic terminals: rxvt and PuTTY.
if [[ $TERM = rxvt* ]] {
  _myzshrc_keys[CtrlPageUp]=$'\e[5^'
  _myzshrc_keys[CtrlPageDown]=$'\e[6^'
  _myzshrc_keys[CtrlDelete]=$'\e[3^'
  _myzshrc_keys[CtrlRightArrow]=$'\eOc'
  _myzshrc_keys[CtrlLeftArrow]=$'\eOd'
} elif ((_myzshrc_putty)) {
  _myzshrc_keys[Home]=$'\e[1~'
  _myzshrc_keys[End]=$'\e[4~'
  _myzshrc_keys[CtrlPageUp]=$'\e\e[5~'              # This is actually Alt+PageUp.
  _myzshrc_keys[CtrlPageDown]=$'\e\e[6~'            # This is actually Alt+PageDown.
  _myzshrc_keys[CtrlDelete]=''                      # Sorry, no Ctrl+Delete.
  _myzshrc_keys[RightArrow]=$'\eOC'
  _myzshrc_keys[LeftArrow]=$'\eOD'
  _myzshrc_keys[CtrlRightArrow]=$'\e[C'
  _myzshrc_keys[CtrlLeftArrow]=$'\e[D'
}

# Bind multiple keys at once.
# $1: Either a key to the _myzshrc_keys array, or multiple keys sequences separated by spaces.
_myzshrc_bindkeys() {
  local keys=$1
  local widget=$2
  local key
  local IFS=' '                                     # Split keys by spaces.
  for key (${=keys}) {                              # Loop through the key sequences.
    if (( ${+_myzshrc_keys[$key]} )) {              # If its a key from the _myzshrc_keys array,
      _myzshrc_bindkeys "${_myzshrc_keys[$key]}" $widget # Recurse.
    } else {
      bindkey $key $widget                          # Bind the key to the widget.
    }
  }
}

# Clear the Zsh's keymaps ----------------------------------------------------------------------- #
# Remove keymaps except .safe and main.
bindkey -D command emacs vicmd viins viopp visual

# Remove most key bindings in the main keymap.
bindkey -r '^'{'[','?',{,'[[','[O'}{A,B,C,D},E,F,G,H,I,K,L,N,O,P,Q,R,S,T,U,V,W,X,Y,Z}

# Basic keyboard bindings ----------------------------------------------------------------------- #
() {
  local widget keycodes keycode
  for widget keycodes (
    backward-delete-char              Backspace
    overwrite-mode                    Insert
    delete-char                       Delete
    beginning-of-line                 Home
    end-of-line                       End
    history-beginning-search-backward PageUp
    history-beginning-search-forward  PageDown
    up-line-or-history                ArrowUp
    down-line-or-history              ArrowDown
    backward-char                     ArrowLeft
    forward-char                      ArrowRight
    expand-or-complete                Tab
    undo                              "^Z"
    redo                              "^Y"
    history-incremental-search-backward "^R"
  ) {
    for keycode (${=keycodes}) {
      _myzshrc_bindkeys $keycode $widget
    }
  }
}

# Send break (Ctrl+D) --------------------------------------------------------------------------- #
# This widget allows Ctrl+D to work even when the buffer is not empty. Pressing Ctrl+D twice on
# a non-empty buffer will close Zsh.
_myzshrc_send_break() {
  BUFFER+='^D'                                      # Add the ^D to the buffer.
  zle send-break                                    # Send a break, similar to clicking Ctrl+C.
}
zle -N _myzshrc_send_break
bindkey '^D' _myzshrc_send_break

# Clear screen (Ctrl+L) ------------------------------------------------------------------------- #
# Zsh's clear-screen doesn't clear the scrollback buffer, this does.
_myzshrc_clear_screen() {
  print -n $'\e[3J'                                 # Clear the scrollback buffer.
  zle clear-screen                                  # Call zle's clear-screen widget.
}
zle -N _myzshrc_clear_screen
bindkey '^L' _myzshrc_clear_screen

# Move to next/previous word (Ctrl+RightArrow / Ctrl + LeftArrow) ------------------------------- #
if [[ $TERM != linux ]] {
  _myzshrc_backward_word() { local WORDCHARS=${WORDCHARS:s#/#}; zle backward-word }
  _myzshrc_forward_word() { local WORDCHARS=${WORDCHARS:s#/#}; zle forward-word }

  # Delete next/previous word (Ctrl+Backspace / Ctrl+Delete)
  # Since xterm emits ^H for backspace, backspace won't work. For a workaround,
  # see https://wiki.archlinux.org/title/Xterm#Fix_the_backspace_key
  _myzshrc_backward_delete_word() { local WORDCHARS=${WORDCHARS:s#/#}; zle backward-delete-word }
  _myzshrc_forward_delete_word() { local WORDCHARS=${WORDCHARS:s#/#}; zle delete-word }

  # Bind the keys.
  () {
    local widget keycode
    for widget keycode (
      _myzshrc_backward_word          CtrlLeftArrow
      _myzshrc_forward_word           CtrlRightArrow
      _myzshrc_backward_delete_word   CtrlBackspace
      _myzshrc_forward_delete_word    CtrlDelete
    ) {
      zle -N $widget && _myzshrc_bindkeys $keycode $widget
    }
  }
}

# zle-line-init and zle-line-finish ------------------------------------------------------------ #
# I think I ran into a bug in add-zle-hook-widget, so we are settings the widgets directly.

zle-line-init() {
  ((${+terminfo[smkx]})) && echoti smkx             # Enable application mode
  _myzshrc_zlelineinit_overwrite                    # Set mode and cursor for overwrite/insert
}

zle-line-finish() {
  ((${+terminfo[rmkx]})) && echoti rmkx             # Disable application mode
}

zle -N zle-line-init
zle -N zle-line-finish

# Insert and overwrite mode --------------------------------------------------------------------- #
_myzshrc_overwrite_state=0                          # Overwrite mode state, 0 = off, 1 = on
_myzshrc_overwrite_prompt=''                        # Overwrite mode indicator for RPROMPT

# Sets cursor shape according to insert/overwrite state and update the indicator.
_myzshrc_cursorshape_overwrite() {
  if ((_myzshrc_overwrite_state)) {                 # In overwrite mode:
    print -n $'\e[?6c'                              # █ cursor on $TERM = linux
    print -n $'\e[3 q'                              # _ cursor on xterm and compatible
  } else {                                          # In insert mode:
    print -n $'\e[?2c'                              # _ cursor on $TERM = linux
    print -n $'\e[5 q'                              # | cursor on xterm and compatible
  }
}

# Update the overwrite mode indicator.
_myzshrc_indicator_overwrite() {
  local overwrite_indicator
  zstyle -s ':myzshrc:prompt' overwrite-indicator overwrite_indicator
  ((_myzshrc_overwrite_state)) \
    && _myzshrc_overwrite_prompt='  '$overwrite_indicator \
    || _myzshrc_overwrite_prompt=''
}

# Handler for the 'Insert' key.
_myzshrc_keyhandler_overwrite() {
  zle overwrite-mode                                # Toggle overwrite mode.
  [[ $ZLE_STATE = *insert* ]]
  _myzshrc_overwrite_state=$?                       # Save the overwrite mode state.
  _myzshrc_cursorshape_overwrite                    # Update the cursor shape.
  _myzshrc_indicator_overwrite                      # Update the indicator.
  # If we're not in the start context, we can't reset the prompt, as it -- for some reasom --
  # will mess up the RPROMPT.
  [[ $CONTEXT = start ]] && zle reset-prompt        # Reset the prompt.
}
zle -N _myzshrc_keyhandler_overwrite
_myzshrc_bindkeys Insert _myzshrc_keyhandler_overwrite

_myzshrc_zlelineinit_overwrite() {
  # Since zle's overwrite mode is not persistent, we need to restore the state on each prompt.
  ((_myzshrc_overwrite_state)) && zle overwrite-mode
  _myzshrc_cursorshape_overwrite
}

zle -N zle-line-init

_myzshrc_overwrite_preexec() {
  # Always reset to insert cursor before running commands.
  print -n $'\e[?2c'                                # _ cursor on $TERM = linux
  print -n $'\e[5 q'                                # │ cursor on xterm and compatible
}

add-zsh-hook preexec _myzshrc_overwrite_preexec

# [ PROMPT SETUP ]------------------------------------------------------------------------------- #
# That's the way I like it.

# Minimal, simple, and fancy prompts ------------------------------------------------------------ #
# A simple prompt that will work nicely in a console with limited charset and only 16 colors,
# such as the Linux console.
_myzshrc_prompt_simple() {
  _myzshrc_prompt=simple
  _myzshrc_prompt_prev=simple
  for g k v (
    prompt prompt-type simple
    prompt before-userhost '%B%F{%(!.1.2)}'
    prompt before-path '%f%b:%B%4F'
    prompt after-path '%f%b%# '
    prompt ssh-indicator '%B%F{243}[%f%bssh%B%F{243}]%f%b '
    prompt overwrite-indicator '%K{4}%B%7F over %f%b%k'
    prompt jobs-indicator '%K{5}%B%7F %j job%(2j.s.) %f%b%k'
    prompt error-indicator '%K{1}%B%7F %? %f%b%k'
    prompt continuation '%B%F{243}» %f%b'
    prompt eol-mark '%B%F{243}¤%f%b'
    gitstatus git-prefix $'%B%1Fgit%f%b'
    gitstatus stash-count '%B%F{243}*'
    gitstatus staged-count '%B%2F+'
    gitstatus unstaged-count '%B%1F+'
    gitstatus untracked-count '%B%1F*'
    gitstatus commits-ahead '%6F%B↑'
    gitstatus commits-behind '%6F%B↓'
    gitstatus push-commits-ahead '%6F%B←'
    gitstatus push-commits-behind '%6F%B→'
    gitstatus action '%B%1F'
    gitstatus num-conflicted '%1F!%B'
  ) { zstyle :myzshrc:$g $k $v; }
  _myzshrc_indicator_overwrite                      # Update the overwrite indicator if needed.
}

# Completely unnecessary, but I like it.
# This prompt requires Nerd Fonts (https://www.nerdfonts.com/).
_myzshrc_prompt_fancy() {
  _myzshrc_prompt=fancy
  _myzshrc_prompt_prev=fancy
  if ((_myzshrc_color24bit)) {
    local userhost_color='%(!.#b24742.#47a730)'
    local path_color='#547bb5'
  } else {
    local userhost_color='%(!.red.green)'
    local path_color=blue
  }
  for g k v (
    prompt prompt-type fancy
    prompt before-userhost "%K{$userhost_color}%B%F{255} "
    prompt before-path %b%F{$userhost_color}%K{$path_color}$'\uE0B4 %B%F{255}'
    prompt after-path %b%F{$path_color}%K{$userhost_color}$'\uE0B4'%k%F{$userhost_color}$'\uE0B4%f '
    prompt ssh-indicator "%K{238}%15F ssh %K{$userhost_color}"
    prompt overwrite-indicator $'%4F\uE0B6%K{4}%B%7Fover%k%b%4F\uE0B4%f'
    prompt jobs-indicator $'%5F\uE0B6%K{5}%B%7F%j job%(2j.s.)%k%b%5F\uE0B4%f'
    prompt error-indicator $'%1F\uE0B6%K{1}%B%7F%?%k%b%1F\uE0B4%f'
    prompt continuation $'%B%F{243}\uf054%f%b'
    prompt eol-mark '%B%F{243}●%b%f'
    gitstatus git-prefix $'%B%208F\uE0A0%f%b'
    gitstatus stash-count '%245F*%B%250F'
    gitstatus staged-count '%106F+%B%154F'
    gitstatus unstaged-count '%167F+%B%210F'
    gitstatus untracked-count '%167F*%B%210F'
    gitstatus commits-ahead '%36F↑%B%86F'
    gitstatus commits-behind '%36F↓%B%86F'
    gitstatus push-commits-ahead '%36F←%B%86F'
    gitstatus push-commits-behind '%36F→%B%86F'
    gitstatus action '%B%210F'
    gitstatus num-conflicted '%167F!%B%210F'
  ) { zstyle :myzshrc:$g $k $v; }
  _myzshrc_indicator_overwrite                      # Update the overwrite indicator if needed.
}

# Minimal prompt. Mainly for screenshots.
_myzshrc_prompt_minimal() {
  _myzshrc_prompt=minimal
  _myzshrc_prompt_prev=minimal
  zstyle -d :myzshrc:prompt
  zstyle -d :myzshrc:gitstatus
  zstyle :myzshrc:prompt prompt-type minimal
  _myzshrc_indicator_overwrite                      # Update the overwrite indicator if needed.
}

# Select the prompt.
# The fancy prompt will be used if the terminal is a virtual TTY, X11 is available, we're using
# a UTF-8 locale, we're not in a SSH session, and the terminal supports 8-bit colors; otherwise
# the simple prompt will be used.
_myzshrc_prompt_select() {
  : ${_myzshrc_prompt:=''}
  : ${_myzshrc_prompt_prev:=''}
  if [[ -n ${_myzshrc_prompt_prev} && $_myzshrc_prompt_prev = $_myzshrc_prompt ]] {
    return
  }
  case ${_myzshrc_prompt} in
    simple) _myzshrc_prompt_simple ;;
    fancy) _myzshrc_prompt_fancy ;;
    minimal) _myzshrc_prompt_minimal ;;
    *) [[ $LANG = *UTF-8* ]] \
        && ! ((_myzshrc_ssh_session)) \
        && [[ -z $TMUX ]] \
        && _myzshrc_prompt_fancy || _myzshrc_prompt_simple
  esac
}

# Precmd hook that resets the terminal and updates the prompt ----------------------------------- #
_myzshrc_prompt_precmd() {
  ret=$?
  _myzshrc_reset_terminal
  _myzshrc_prompt_select
  if (( $ret )) {
    print -rn $'\e]133;D;'"$ret"';aid=$\e\\'
    print -rn $'\a'
  }
  print -rn $'\e]133;A;cl=m;aid=$\e\\'
  if [[ $_myzshrc_prompt = 'minimal' ]] {
    # Minimal prompt is a special case, since it doesn't include the user/host, and neither
    # has any RPROMPT/RPS2.
    PS1='%# '
    PS2='> '
    RPS2=''
    RPROMPT=''
  } else {
    local prompt_type \
          before_userhost before_path after_path \
          ssh_indicator overwrite_indicator jobs_indicator error_indicator \
          continuation eol_mark gitstatus_prompt

    zstyle -s :myzshrc:prompt prompt-type prompt_type
    zstyle -s :myzshrc:prompt before-userhost before_userhost
    zstyle -s :myzshrc:prompt before-path before_path
    zstyle -s :myzshrc:prompt after-path after_path
    zstyle -s :myzshrc:prompt ssh-indicator ssh_indicator
    zstyle -s :myzshrc:prompt overwrite-indicator overwrite_indicator
    zstyle -s :myzshrc:prompt jobs-indicator jobs_indicator
    zstyle -s :myzshrc:prompt error-indicator error_indicator
    zstyle -s :myzshrc:prompt continuation continuation
    zstyle -s :myzshrc:prompt eol-mark eol_mark

    _myzshrc_gitstatus_prompt_update

    PS1=''
    ((_myzshrc_ssh_session)) && PS1+=$ssh_indicator
    PS1+="${before_userhost}%(!..%n@)%m${before_path}%~${after_path}"

    RPROMPT="\${_myzshrc_overwrite_prompt}"
    RPROMPT+="%(1j.  $jobs_indicator.)"
    RPROMPT+="%(0?..  $error_indicator)"
    RPROMPT+=$gitstatus_prompt

    # Indicate Python venv in the RPROMPT.
    if (( ${${VIRTUAL_ENV:+1}:-0} )) \
      RPROMPT+=$' %F{#4b8bbe}(venv %F{#ffe873}'"$(basename "$VIRTUAL_ENV")"$'%F{#4b8bbe})%f'

    if (( ${${IN_NIX_SHELL:+1}:-0} )) \
      RPROMPT+=$' %F{#7ebae4}(nix-shell)%f'

    local level
    PS2=''; for level ({1..16}) { PS2+="%(${level}_.${continuation}.)" }; PS2+=' '

    # RPS2 will be type of the current open block (if, while, for, etc.)
    # Make RPS2 show [cont] when we're in a continuation line (the previous line ended with '\').
    RPS2='%B%F{black}[%f%b${${(%):-%^}//(#s)(#e)/cont}%B%F{black}]%f%b'
  }
  PROMPT_EOL_MARK=${eol_mark}
  # Add semantic integration, as described in
  # https://gitlab.freedesktop.org/Per_Bothner/specifications/blob/master/proposals/semantic-prompts.md
  PS1=$'%{\e]133;P;k=i\e\\%}'$PS1$'%{\e]133;B\e\\%}'
  PS2=$'%{\e]133;P;k=s\e\\%}'$PS2$'%{\e]133;B\e\\%}'
  if [[ -n $RPS2 ]] RPS2=$'%{\e]133;P;k=r\e\\%}'$RPS2$'%{\e]133;B\e\\%}'
  if [[ -n $RPROMPT ]] RPROMPT=$'%{\e]133;P;k=r\e\\%}'$RPROMPT$'%{\e]133;B\e\\%}'
}

_myzshrc_prompt_preexec() {
  # This is also for semantic integration.
  print -rn -- $'\e]133;C;\e\\'
}

add-zsh-hook precmd _myzshrc_prompt_precmd
add-zsh-hook preexec _myzshrc_prompt_preexec

# Window title ---------------------------------------------------------------------------------- #
# Ellipsize a path to display it in a limited space.
_myzshrc_ellipsized_path() {
  (( ${#1} <= 40 )) && { print -rn -- $1; return }  # If the path is short enough, just return it.
  local array=(${(s:/:)1})                          # Split the path into an array.
  local head=() tail=()                             # The head and tail of the path.
  local prefix=''                                   # '/' if the path is absolute, '' otherwise.
  [[ ${1[1]} == '/' ]] && prefix='/'                # If the path is absolute, set the prefix.
  local next=tail                                   # The next part of the path to be added.
  local result                                      # The result.
  local elm                                         # The current element being processed.
  for (( i=1; $i <= ${#array}; i++ )) {             # Ellipsize elements bigger than 23 characters.
    (( ${#array[$i]} > 23 )) && array[$i]=${array[$i]:0:20}…
  }
  while (( ${#:-${prefix}${(j:/:)head}/…/${(j:/:)tail}} < 40 && ${#array} )) {
    # While the path is too long and there are still elements to process:
    case $next {       # Select the next part of the path to be added and remove it from the array.
      head) elm=$array[1]; shift array ;;
      tail) elm=$array[-1]; shift -p array ;;
    }
    if (( ${#:-${prefix}${(j:/:)head}/${elm}/${(j:/:)tail}} > 40 && ${#elm} > 3 )) {
      elm='…'                                       # If it would be too long, replace it with '…'.
    }
    case $next {                                    # Add the element to the path.
      head) head+=($elm); next=tail ;;
      tail) tail=($elm $tail); next=head ;;
    }
    [[ ${elm} == '…' ]] && break                    # If we had to ellipsize the path, stop.
  }
  if (( ${#array} == 1 && ${#${array[1]}} <= 3 )) { # If a single elm is left with len<=3, add it.
    head+=($array[1])
  } elif (( ${#array} )) {                          # If there are still elements left, add '…'.
    head+=('…')
  }
  result=${prefix}${(j:/:)head}/${(j:/:)tail}       # Join everything together.
  result=${result//\/…\/…/\/…}                      # Remove any '…/…' sequences.
  result=${result//\/…\/…/\/…}                      # Remove any '…/…' sequences.
  result=${result//\/…\/…/\/…}                      # Remove any '…/…' sequences.
  result=${result//[[:blank:]]…/…}                  # Remove any spaces before ellipses.
  print -rn -- $result
}

_myzshrc_print_window_title() {
  local cwd=$(_myzshrc_ellipsized_path ${(%):-%~})  # Get the current directory (ellipsized).
  local cmd=$1                                      # Get the command name.
  cwd=${cwd//[[:cntrl:]]/ }                         # Strip control characters from the path.
  cmd=${cmd//[[:cntrl:]]/ }                         # Strip control characters from the commmand.
  print -n $'\e]0;'                                 # Start the title escape sequence.
  if [[ -z $TMUX ]] {
    ((_myzshrc_ssh_session)) && print -n '🌎'       # Show we're running through SSH.
    ((! UID)) && print -n '🔓'                      # Add an unlocked lock emoji if user is root.
    ((_myzshrc_ssh_session)) && print -Pn ' [%m]'   # Show the SSH hostname.
    ((! UID||_myzshrc_ssh_session)) && print -n ' ' # Add a space if we're root or SSH.
    print -nr -- $cwd                               # Print the path.
    print -n ' • '                                  # Add a separator.
  }
  print -nr -- $cmd                                 # Print the command name.
  print -n $'\e\\'                                  # End the title escape sequence.
  if [[ -n $TMUX ]] {
     tmux set -p '@myzshrc-current-directory' $cwd  # Set the current directory for tmux.
  }
}

_myzshrc_window_title_precmd() {                    # After the command is run, we're back in zsh,
  _myzshrc_print_window_title zsh                   # so let the window name reflect that.
}

_myzshrc_window_title_preexec() {
  local cmd=$2
  [[ ${#cmd} -gt 32 ]] && cmd="${cmd[1,31]}…"       # Truncate the command line if it's too long.
  _myzshrc_print_window_title ${cmd}                # Show the command name in the window title.
}

add-zsh-hook precmd _myzshrc_window_title_precmd
add-zsh-hook preexec _myzshrc_window_title_preexec

# [ REPORT CWD WITH OSC 7 ]---------------------------------------------------------------------- #
_myzshrc_osc7_chpwd() {
  if (( ! ZSH_SUBSHELL )) {
    emulate -L zsh # also sets localoptions for us
    setopt extendedglob
    local LC_ALL=C
    printf '\e]7;file://%s%s\e\' $HOST ${PWD//(#m)([^@-Za-z&-;_~])/%${(l:2::0:)$(([##16]#MATCH))}}
  }
}

add-zsh-hook -Uz chpwd _myzshrc_osc7_chpwd

# Show git status in RPROMPT -------------------------------------------------------------------- #
# On Arch Linux, install the gitstatus, gitstatus-bin or gitstatus-git packages from AUR.
# For other distros, cf. https://github.com/romkatv/gitstatus.
GITSTATUS_PLUGIN=${${commands[gitstatusd]}:A:h}/../share/gitstatus/gitstatus.plugin.zsh

if [[ -n ${commands[git]} && -r $GITSTATUS_PLUGIN ]] {
  source $GITSTATUS_PLUGIN

  _myzshrc_gitstatus_started=0                      # Whether gitstatus has been started.
  _myzshrc_gitstatus_last_active=$EPOCHSECONDS      # Last time gitstatus was active.

  # Sets GITSTATUS_PROMPT to reflect the state of the current git repository.
  _myzshrc_gitstatus_prompt_update() {
    gitstatus_prompt=''                             # Reset git status prompt.

    # If we're not in a git repo, or if we are but it's on a remote filesystem, do not start
    # gitstatusd, and if it's been inactive for more than 2 minutes, stop it.
    () {
      local curdir=$PWD
      while [[ $curdir != "/" ]] {                  # Scan up the directory tree.
        if [[ -d $curdir/.git ]] break              # Stop once we find a git repo.
        curdir=${curdir:h}                          # Go up one level.
      }
      if [[ ! -d "$curdir/.git" ]] return 0         # Succeed if we're not in a git repo.
      _myzshrc_fstypecache_get                      # Get the filesystem type of the current dir.
      if [[ $REPLY = (automount|fuse.sshfs|fuse.curlftpfs|nfs) ]] {
        return 0 # Succeed if it's a remote filesystem.
      }
      return 1                                      # Otherwise, fail.
    } && {
      if (( _myzshrc_gitstatus_started && _myzshrc_gitstatus_last_active < (EPOCHSECONDS - 120) )) {
        gitstatus_stop 'MY'                         # Stop gitstatusd instance with name "MY".
        _myzshrc_gitstatus_started=0
      }
      return
    }

    # Start gitstatusd instance with name "MY". The same name is passed to gitstatus_query in
    # _myzshrc_gitstatus_prompt_update. The flags with -1 as values enable staged, unstaged,
    # conflicted and untracked counters.
    if (( ! _myzshrc_gitstatus_started )) {
      gitstatus_start -s -1 -u -1 -c -1 -d -1 'MY'
      _myzshrc_gitstatus_started=1
    }
    _myzshrc_gitstatus_last_active=$EPOCHSECONDS

    # Call gitstatus_query synchronously. Note that gitstatus_query can also be
    # called asynchronously; see documentation in gitstatus.plugin.zsh.
    gitstatus_query 'MY'                  || return 1  # error
    [[ $VCS_STATUS_RESULT == 'ok-sync' ]] || return 0  # not a git repo

    local git_prefix stash_count staged_count unstaged_count untracked_count commits_behind \
          commits_ahead push_commits_behind push_commits_ahead action num_conflicted

    zstyle -s :myzshrc:gitstatus git-prefix git_prefix
    zstyle -s :myzshrc:gitstatus stash-count stash_count
    zstyle -s :myzshrc:gitstatus staged-count staged_count
    zstyle -s :myzshrc:gitstatus unstaged-count unstaged_count
    zstyle -s :myzshrc:gitstatus untracked-count untracked_count
    zstyle -s :myzshrc:gitstatus commits-ahead commits_ahead
    zstyle -s :myzshrc:gitstatus commits-behind commits_behind
    zstyle -s :myzshrc:gitstatus push-commits-ahead push_commits_ahead
    zstyle -s :myzshrc:gitstatus push-commits-behind push_commits_behind
    zstyle -s :myzshrc:gitstatus action action
    zstyle -s :myzshrc:gitstatus num-conflicted num_conflicted

    local p="  ${git_prefix} "                      # Git status prefix
    local where                                     # Branch name, tag or commit
    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]] {
      where=$VCS_STATUS_LOCAL_BRANCH                # Use local branch name, e.g. 'master'.
    } elif [[ -n $VCS_STATUS_TAG ]] {
      p+='%F{243}%B#%b%f'                           # Add # to signify a tag.
      where=$VCS_STATUS_TAG                         # Use tag name, e.g. '#v1.0.0'.
    } else {
      p+='%F{243}%B@%b%f'                           # Add @ to signify a commit.
      where=${VCS_STATUS_COMMIT[1,8]}               # Use commit hash (8 chars), e.g. '@04bbb413'.
    }
    (($#where > 32)) && where[13,-13]="…"           # truncate long branch names/tags
    p+="${where//\%/%%}"                            # escape '%'

    local value style

    for value style (
      $VCS_STATUS_STASHES $stash_count
      $VCS_STATUS_NUM_STAGED $staged_count
      $VCS_STATUS_NUM_UNSTAGED $unstaged_count
      $VCS_STATUS_NUM_UNTRACKED $untracked_count
      $VCS_STATUS_COMMITS_BEHIND $commits_behind
      $VCS_STATUS_COMMITS_AHEAD $commits_ahead
      $VCS_STATUS_PUSH_COMMITS_BEHIND $push_commits_behind
      $VCS_STATUS_PUSH_COMMITS_AHEAD $push_commits_ahead
      $VCS_STATUS_NUM_CONFLICTED $num_conflicted
    ) {
      ((value)) && p+=" ${style}${value}%b%f"
    }
    [[ -n $VCS_STATUS_ACTION ]] && p+=" ${action}${VCS_STATUS_ACTION}%b%f"

    gitstatus_prompt="${p}"
  }
} else {
  _myzshrc_gitstatus_prompt_update() {
    gitstatus_prompt=""
  }
}
# ----------------------------------------------------------------------------------------------- #


# [ COMPLETION SETUP ] -------------------------------------------------------------------------- #
if [[ -f /etc/NIXOS ]] {
  for profile ( ${(z)NIX_PROFILES} ) {
    fpath+=( $profile/share/zsh/site-functions )
    fpath+=( $profile/share/zsh/$ZSH_VERSION/functions )
    fpath+=( $profile/share/zsh/vendor-completions )
  }
}
() {
  local ZCOMPDUMP="$_myzshrc_tmp/zcompcache/zcompdump"
  if (( EPOCHSECONDS - $( [[ -e $ZCOMPDUMP ]] && zstat +mtime $ZCOMPDUMP || print 0 ) > 1000 )) {
    compinit -d $ZCOMPDUMP
  } else {
    compinit -C -d $ZCOMPDUMP
  }
}
bindkey -r '^X'{'^R','?',C,a,c,d,e,h,m,n,t,'~'} '^['{',',/,'~'}
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path $_myzshrc_tmp/zcompcache
zstyle ':completion:*' completer _complete _prefix
zstyle ':completion:*' add-space true
zstyle ':completion:*:*:*:*:*' menu select
zstyle ":completion:*:commands" rehash 1
zstyle ':completion:*:default' list-colors $ls_colors
zstyle ':completion:*:warnings' format '%B%F{red}No matches for %d.%f%b'
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:descriptions' format '%B%K{cyan}%F{white}  %d  %f%k%b'
zstyle ':completion:*' group-name ""
zstyle ':completion:*' accept-exact '*(N)'

# Processes ------------------------------------------------------------------------------------- #
zstyle ':completion:*:processes' menu yes select
zstyle ':completion:*:processes' force-list always
zstyle ':completion:*:processes' command 'ps -eo pid,user,cmd'
zstyle ':completion:*:processes' list-colors "=(#b) #([0-9]#)*=0=01;32"
zstyle ':completion:*:processes-names' command "ps -eo exe= |sed -e 's,^.*/,,g' |sort -f |uniq"
zstyle ':completion:*:processes-names' list-colors '=*=01;32'

# ssh, scp, sftp and sshfs -----------------------------------------------------------------------#
# Load ssh hosts from ~/.ssh/config
local -a ssh_hosts=()
if [[ -r ~/.ssh/config ]] {
  ssh_hosts=(${${${(@M)${(f)"$(<~/.ssh/config)"}:#Host *}#Host }:#*[*?]*}) 2>/dev/null
  ssh_hosts=(${(s/ /)${ssh_hosts}})
  if (( ${#ssh_hosts} )) {
    zstyle ':completion:*:scp:*' hosts $ssh_hosts
    zstyle ':completion:*:sftp:*' hosts $ssh_hosts
    zstyle ':completion:*:ssh:*' hosts $ssh_hosts
    zstyle ':completion:*:sshfs:*' hosts $ssh_hosts
  }
}
zstyle ':completion:*:scp:*' users
zstyle ':completion:*:sftp:*' users
zstyle ':completion:*:ssh:*' users
zstyle ':completion:*:sshfs:*' users
# Workaround for sshfs
[[ -n ${commands[sshfs]} ]] && _user_at_host() { _ssh_hosts "$@" }
# Don't complete hosts from /etc/hosts
zstyle -e ':completion:*' hosts 'reply=()'

# Hide entries from completion ------------------------------------------------------------------ #
zstyle ':completion:*:parameters' ignored-patterns \
  '(_*|(chpwd|periodic|precmd|preexec|zshaddhistory|zshexit)_functions|PERIOD)'
zstyle ':completion:*:functions' ignored-patterns \
  '(_*|pre(cmd|exec)|TRAP*)'
zstyle ':completion:*' single-ignored show
# ----------------------------------------------------------------------------------------------- #


# [ EXIT MESSAGE ]------------------------------------------------------------------------------- #
# Print a message when exiting the shell.
_myzshrc_exit_message_zshexit() {
  print -P "%B%F{243}-----%f zsh%b (%B%F{yellow}$$%f%b) %Bfinished %F{243}-----%f%b"
}
add-zsh-hook zshexit _myzshrc_exit_message_zshexit
# ----------------------------------------------------------------------------------------------- #


# [ COMMANDS ]----------------------------------------------------------------------------------- #
# Functions and aliases.

# Customize and colorize some commands ---------------------------------------------------------- #
# Set the default flags for ls:
#   -h: human readable sizes (e.g. 1K 2M 4G)
#   --color=auto: use colors when output is a terminal
#   --indicator-style=slash: use a slash to indicate directories
#   --time-style=long-iso: show times in long ISO format (e.g. 2017-01-01 12:00)
alias ls='command ls -h -p --color=auto --group-directories-first --time-style=long-iso'
() {
  local g
  for g ({{,bz,lz,zstd,xz}{,e,f},pcre{,2}}grep) {   # Add colors to grep and friends.
    [[ -n ${commands[$g]} ]] && alias "$g=command $g --color=auto"
  }
}
alias diff='command diff --color=auto'              # Add colors to diff command.
alias ip='command ip --color=auto'                  # Add colors to ip command.
[[ -n $commands[python3] && -z $commands[python] ]] \
  && alias python=python3                           # Alias python to python3 when not found

# nmed - use vared to rename a file ------------------------------------------------------------- #
nmed() {
  local fname
  for fname ("$@") {
    local old=$fname
    local new=$fname
    if [[ -e $old ]] {
      print -Pn '%B%F{cyan}Old name%b:%f %B'
      print -r -- $old
      vared -e -p '%B%F{cyan}New name%b:%f %B' new \
        && print -Pn '%b' && mv -i -v -- $old $new
    } else {
      >&2 print -r "nmed: \`$old': File not found."
    }
  }
}

# isodate - print the current date in ISO format ------------------------------------------------ #
isodate() {
    if [[ $1 =~ '^--utc|-u$' ]] {
    print -r -- $(date -u +%Y-%m-%d)
  } else {
    print -r -- $(date +%Y-%m-%d)
  }
}

# isotime - print the current time in ISO format ------------------------------------------------ #
isotime() {
  if [[ $1 =~ '^--utc|-u$' ]] {
    print -r -- $(date -u +%H:%M:%S)
  } else {
    print -r -- $(date +%H:%M:%S)
  }
}

# detach - run a command in the background ------------------------------------------------------ #
detach() {
  ( nohup "$@" >/dev/null 2>&1 & )
}

# sshfs-sudo - mount sshfs remote with root privileges using sudo ------------------------------- #
if [[ -n ${commands[sshfs]} ]] {
  sshfs-sudo() {
    # The sftp_server option sed's through /etc/ssh/ssh_config to find the sftp server, and then
    # runs it with sudo.
    sshfs -o sftp_server='/usr/bin/env sudo "$(sed -nE "/^\\s*subsystem\\s+/I{s///;s/\\s*(|#.*)$//;s/sftp\\s+//p}" /etc/ssh/sshd_config)"' "$@"
  }
}

# tmux - show a nice menu to select session when tmux is run without any parameters ------------- #
tmux() {
  if [[ $# -ne 0 || -z ${commands[fzf]} ]] {
    command tmux "$@"
  } else {
    setopt local_options pipefail
    local PADDING_HORIZONTAL=$(( (COLUMNS / 2) - 33 ))
    local PADDING_HORIZONTAL=$(( PADDING_HORIZONTAL > 0 ? PADDING_HORIZONTAL : 0 ))
    local FZF_FORMAT=$'\e[33m#{session_id}\e[0m\t#{=/21/…:#{p21:session_name}}\t'
    FZF_FORMAT+=$'#{session_windows}\t#{t/f/%Y-%m-%d %H#:%M#:%S/:session_created}'
    local CREATE_NEW_SESSION='<Create new session>'
    local RESPONSE=$(
      (
        tmux list-sessions -F "$FZF_FORMAT" 2>/dev/null | sort -k1.7n,2
        print -Pr -- "%B%F{black}${CREATE_NEW_SESSION}%b%f"
      ) | fzf -1 --ansi --margin=30%,$PADDING_HORIZONTAL --prompt='⟩ ' --pointer='►' --cycle \
          --border=rounded --header $'id\tname\t\t\t#win\tcreated' --layout=reverse --info=hidden \
        | sed -E 's,\t.*,,g'
    )
    if (( $? )) return 1
    if [[ "$RESPONSE" = $CREATE_NEW_SESSION ]] {
      RESPONSE="$(TMUX= tmux new-session -dP)"
    }
    if [[ -n $TMUX ]] {
      tmux switch-client -t "$RESPONSE"
    } else {
      tmux attach -t "$RESPONSE"
    }
  }
}

# dockersh - run a shell inside a docker container ---------------------------------------------- #
dockersh() {
  if [[ $# -ne 0 || -z ${commands[fzf]} || -z ${commands[docker]} ]] {
    command dockersh "$@"
  } else {
    setopt local_options pipefail
    local PADDING_HORIZONTAL=$(( (COLUMNS / 2) - 60 ))
    local PADDING_HORIZONTAL=$(( PADDING_HORIZONTAL > 0 ? PADDING_HORIZONTAL : 0 ))
    docker ps --format '{{.ID}}  {{.Image}} / {{.Names}}' \
      | fzf -m -1 --ansi --margin=30%,$PADDING_HORIZONTAL --prompt='⟩ ' --pointer='►' \
            --cycle --border=rounded --header 'name          image / container' --layout=reverse \
            --info=hidden \
      | sed 's/ .*//g' \
      | xargs -I'{}' -o docker exec -ti {} sh -c '
          if [ -x /bin/bash ]; then
            /bin/bash
          else
            /bin/sh
          fi
      '
  }
}
# ----------------------------------------------------------------------------------------------- #


# [ AUTO LOGOUT ]-------------------------------------------------------------------------------- #
if [[ $TTY =~ '/dev/ttyS?[0-9]+' ]] {
  TMOUT=300                                         # 5 minutes
}
# ----------------------------------------------------------------------------------------------- #


# [ LOAD PLUGINS (SECOND PART) ]----------------------------------------------------------------- #
# Load the rest of the plugins.

# zsh syntax highlighting ----------------------------------------------------------------------- #
# renovate: datasource=github-tags depName=zsh-users/zsh-syntax-highlighting
ZSH_SYNTAX_HIGHLIGHTING_VERSION=0.8.0

_myzshrc_dependency \
  zsh-syntax-highlighting \
  https://github.com/zsh-users/zsh-syntax-highlighting/tarball/${ZSH_SYNTAX_HIGHLIGHTING_VERSION} \
  && {
    zsh-defer source ~/.zshrc-deps/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh

    # Disable syntax highlighting when under network directories.
    _myzshrc_disable_syntax_highlight_on_netfs_precmd() {
      if [[ -n $ZSH_HIGHLIGHT_VERSION ]] {
        _myzshrc_fstypecache_get                    # Get the filesystem type of the cur dir.
        if [[ $REPLY = (automount|fuse.sshfs|fuse.curlftpfs|nfs) ]] { # Check if it's a network fs.
          ZSH_HIGHLIGHT_MAXLENGTH=0                 # Disable syntax highlight if it is.
        } else {
          unset ZSH_HIGHLIGHT_MAXLENGTH             # Enable it otherwise.
        }
      }
    }
    add-zsh-hook precmd _myzshrc_disable_syntax_highlight_on_netfs_precmd
  }

# zsh history substring search ------------------------------------------------------------------ #
# renovate: datasource=git-refs depName=https://github.com/zsh-users/zsh-history-substring-search branch=master
ZSH_HISTORY_SUBSTR_SEARCH_DIGEST=8dd05bfcc12b0cd1ee9ea64be725b3d9f713cf64

_myzshrc_dependency \
  zsh-history-substring-search \
  https://github.com/zsh-users/zsh-history-substring-search/tarball/${ZSH_HISTORY_SUBSTR_SEARCH_DIGEST} \
  && {
    zsh-defer source ~/.zshrc-deps/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh

    # Bind Ctrl+PageUp and Ctrl+PageDown to history-substring-search-{up,down}.
    _myzshrc_bindkeys CtrlPageUp history-substring-search-up
    _myzshrc_bindkeys CtrlPageDown history-substring-search-down
  }

# zsh completions ------------------------------------------------------------------------------- #
# renovate: datasource=github-tags depName=zsh-users/zsh-completions
ZSH_COMPLETIONS_VERSION=0.35.0

_myzshrc_dependency \
  zsh-completions \
  https://github.com/zsh-users/zsh-completions/tarball/${ZSH_COMPLETIONS_VERSION} \
  && {
    zsh-defer source ~/.zshrc-deps/zsh-completions/zsh-completions.plugin.zsh
  }

# zsh-nix-shell --------------------------------------------------------------------------------- #
[[ -f /etc/NIXOS ]] && [[ -x /run/current-system/sw/share/zsh-nix-shell/nix-shell.plugin.zsh ]] \
  && zsh-defer source /run/current-system/sw/share/zsh-nix-shell/nix-shell.plugin.zsh


# [ UNSET UNNEEDED VARIABLES AND FUNCTIONS ]----------------------------------------------------- #
unset ZSH_HISTORY_SUBSTR_SEARCH_DIGEST ZSH_SYNTAX_HIGHLIGHTING_VERSION ZSH_COMPLETIONS_VERSION
unset _myzshrc_keys _myzshrc_putty
unset -f _myzshrc_bindkeys _myzshrc_dependency
# ----------------------------------------------------------------------------------------------- #


return 0


# [ APPENDIX: DIR_COLORS ]----------------------------------------------------------------------- #
:<<DIR_COLORS_APPENDIX
COLORTERM ?*

TERM Eterm
TERM ansi
TERM *color*
TERM con[0-9]*x[0-9]*
TERM cons25
TERM console
TERM cygwin
TERM *direct*
TERM dtterm
TERM gnome
TERM hurd
TERM jfbterm
TERM konsole
TERM kterm
TERM linux
TERM linux-c
TERM mlterm
TERM putty
TERM rxvt*
TERM screen*
TERM st
TERM terminator
TERM tmux*
TERM vt100
TERM xterm*

RESET       0         # reset to "normal" color
NORMAL      0         # no color code at all
FILE        0         # regular file: use no color at all
DIR         1;34      # directory
LINK        1;36;3    # symbolic link.
MULTIHARDLINK  0      # regular file with more than one link
FIFO        1;37;45   # pipe
SOCK        1;37;45   # socket
DOOR        1;37;45   # door
BLK         1;33      # block device driver
CHR         1;33      # character device driver
ORPHAN      0;31;3    # symlink to nonexistent or non-stat'able file, ...
MISSING     1;30;3    # ... and the files they point to
SETUID      1;37;41   # file that is setuid (u+s)
SETGID      0;30;43   # file that is setgid (g+s)
CAPABILITY  0;30;41   # file with capability
STICKY_OTHER_WRITABLE  0;30;42  # dir that is sticky and other-writable (+t,o+w)
OTHER_WRITABLE  0;34;42  # dir that is other-writable and not sticky (-t,o+w)
STICKY      1;37;44   # dir that is sticky and not other-writable (+t,o-w)
EXEC        1;32      # files with execute permission.

# -----------------------------
# Archives and compressed files
# -----------------------------
# compressed files
.br         0;91
.bz2        0;91
.gz         0;91
.lz         0;91
.lz4        0;91
.lzma       0;91
.lzo        0;91
.xz         0;91
.z          0;91
.Z          0;91
.zst        0;91
.zstd       0;91
# tar archives and compressed tar archives
.tar        0;91
.tbz2       0;91
.tgz        0;91
.tpxz       0;91
.txz        0;91
.tz         0;91
.tzst       0;91
# other archives
.7z         0;91
.rar        0;91
.zip        0;91
# misc linux packages
.cpio       0;91
.deb        0;91
.rpm        0;91
# disk image
.dmg        0;91
.img        0;91
.iso        0;91
.nrg        0;91
.squashfs   0;91
# java archive
.ear        0;91
.jar        0;91
.war        0;91
# windows archives
.cab        0;91
.wim        0;91

# ---------------------------------------
# Multimedia files (images, audio, video)
# ---------------------------------------
# audio files
.3ga        0;95
.aac        0;95
.aif        0;95
.aiff       0;95
.alac       0;95
.amr        0;95
.ape        0;95
.flac       0;95
.m4a        0;95
.mka        0;95
.mp3        0;95
.mpc        0;95
.oga        0;95
.ogg        0;95
.opus       0;95
.spx        0;95
.wav        0;95
.wv         0;95
# midi/mod and similar
.it         0;95
.mid        0;95
.midi       0;95
.mod        0;95
.s3m        0;95
.xm         0;95
# playlists and similar
.cue        0;95
.m3u        0;95
.m3u8       0;95
.pls        0;95
.xspf       0;95
# vector graphics
.ai         0;95
.cdr        0;95
.djvu       0;95
.dwf        0;95
.dwg        0;95
.emf        0;95
.eps        0;95
.pdf        0;95
.ps         0;95
.svg        0;95
.svgz       0;95
# raster graphics
.avci       0;95
.avcs       0;95
.avif       0;95
.avifs      0;95
.bmp        0;95
.gif        0;95
.heic       0;95
.heics      0;95
.heif       0;95
.heifs      0;95
.jb2        0;95
.jbig2      0;95
.jpeg       0;95
.jpg        0;95
.pbm        0;95
.pgm        0;95
.png        0;95
.pnm        0;95
.ppm        0;95
.psd        0;95
.tga        0;95
.tif        0;95
.tiff       0;95
.webp       0;95
.xbm        0;95
.xpm        0;95
.xcf        0;95
# font files
.eot        0;95
.otf        0;95
.ttc        0;95
.ttf        0;95
.woff       0;95
.woff2      0;95
# video files
.3g2        0;95
.3gp        0;95
.avi        0;95
.flv        0;95
.m4v        0;95
.mkv        0;95
.mov        0;95
.mp4        0;95
.mpeg       0;95
.mpg        0;95
.ogm        0;95
.ogv        0;95
.ogx        0;95
.rm         0;95
.rmvb       0;95
.vob        0;95
.webm       0;95
.wmv        0;95

# ---------------------------------------------------
# Text files: source code, plain text, documents, &c.
# ---------------------------------------------------
# Text / document files
.adoc       0;36
.asc        0;36
.azw        0;36
.azw1       0;36
.azw3       0;36
.chm        0;36
.doc        0;36
.docx       0;36
.dot        0;36
.dotx       0;36
.epub       0;36
.hlp        0;36
.htm        0;36
.html       0;36
.indd       0;36
.log        0;36
.ly         0;36
.lytex      0;36
.md         0;36
.mobi       0;36
.mscz       0;36
.nb         0;36
.nfo        0;36
.odb        0;36
.odf        0;36
.odg        0;36
.odm        0;36
.odp        0;36
.ods        0;36
.odt        0;36
.otg        0;36
.oth        0;36
.otp        0;36
.ots        0;36
.ott        0;36
.pfm        0;36
.pgl        0;36
.ppt        0;36
.pptx       0;36
.rst        0;36
.sib        0;36
.srt        0;36
.tex        0;36
.txt        0;36
.vcard      0;36
.xls        0;36
.xlsx       0;36
.xlt        0;36
.xltx       0;36
# Source code
.ada        0;36
.asm        0;36
.awk        0;36
.bat        0;36
.c          0;36
.c++        0;36
.cc         0;36
.cfg        0;36
.cls        0;36
.cmd        0;36
.cnf        0;36
.conf       0;36
.cpp        0;36
.cs         0;36
.css        0;36
.csv        0;36
.cxx        0;36
.dart       0;36
.dtd        0;36
.go         0;36
.h          0;36
.h++        0;36
.hh         0;36
.hpp        0;36
.hs         0;36
.hxx        0;36
.inc        0;36
.ini        0;36
.java       0;36
.js         0;36
.json       0;36
.jsp        0;36
.jsx        0;36
.kt         0;36
.lisp       0;36
.lua        0;36
.m          0;36
.m4         0;36
.nim        0;36
.nix        0;36
.p          0;36
.pas        0;36
.php        0;36
.pl         0;36
.proto      0;36
.py         0;36
.rb         0;36
.s          0;36
.S          0;36
.scheme     0;36
.scm        0;36
.sh         0;36
.sql        0;36
.toml       0;36
.ts         0;36
.tsx        0;36
.xml        0;36
.xslt       0;36
.yaml       0;36
.yml        0;36
.zig        0;36
.zsh        0;36

# -------------------------------
# Backups / parts / temporary etc
# -------------------------------
*~          0;90
*#          0;90
.bkp        0;90
.bak        0;90
.old        0;90
.orig       0;90
.part       0;90
.rej        0;90
.swp        0;90
.tmp        0;90
.pacsave    0;90
.dpkg-old   0;90
.ucf-dist   0;90
.ucf-old    0;90
.rpmorig    0;90
.rpmsave    0;90
DIR_COLORS_APPENDIX
# ----------------------------------------------------------------------------------------------- #


# vim: set ts=2 sw=2 tw=100 et :
