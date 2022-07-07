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


# [ LOAD FUNCTIONS AND MODULES ]----------------------------------------------------------------- #
zmodload zsh/parameter
zmodload -F zsh/stat b:zstat
# ----------------------------------------------------------------------------------------------- #


# [ SOME SANE DEFAULTS ]------------------------------------------------------------------------- #
umask 0022                                          # As much as I'd like to use 0077, it always
                                                    # causes some problems for me.
export EDITOR=vim                                   # Use vim as the default editor.
export GPG_TTY=$TTY                                 # Set the TTY for GPG pinentry.

# Paths ----------------------------------------------------------------------------------------- #
() {
  typeset -gxUT PATH path ':'; path=()
  typeset -gxUT LD_LIBRARY_PATH ld_library_path ':'; ld_library_path=()

  append_path() {
    local var=$1
    shift
    for dir ($@) {
      [[ ! -e $dir || -h $dir ]] && continue        # Skip if it doesn't exist or it is a symlink.
      (($(zstat +mode $dir) != 16877)) && continue  # Skip if mode is not 40775.
      (($(zstat +uid $dir) != 0)) && continue       # Skip if owner is not root.
      (($(zstat +gid $dir) != 0)) && continue       # Skip if group is not root.
      eval ${var}+='( $dir )'                       # Add directory to the path.
    }
  }

  append_path path /{usr/{local/,},}{s,}bin
  append_path path /usr/{,local/}games
  append_path path /snap/bin

  append_path ld_library_path /{usr/{local/,},}lib{,64,32}
}

# Dynamic linker -------------------------------------------------------------------------------- #
typeset -gxr LD_PRELOAD=''                          # Disable LD_PRELOAD.
typeset -gtx LD_AUDIT=''                            # Disable LD_AUDIT.
typeset -gtx LD_DYNAMIC_WEAK=0                      # Do not allow weak symbols to be overridden.
typeset -gtx LD_POINTER_GUARD=1                     # Enable pointer guard.
# ----------------------------------------------------------------------------------------------- #


# [ LOAD SCRIPTS FROM /ETC/PROFILE.D ]----------------------------------------------------------- #
append_path() {                                     # Append a path to the PATH variable.
  emulate -L zsh                                    # This function will be available for scripts
  path+=($1)                                        # in /etc/profile.d.
}
setopt null_glob
for script (/etc/profile.d/*.sh) {
  [[ -x "$script" ]] && emulate bash -c "source $script"  # Source script using bash emulation.
}
setopt no_null_glob
# ----------------------------------------------------------------------------------------------- #


# [ UNSET UNNEEDED FUNCTIONS ]------------------------------------------------------------------- #
unset -f append_path
# ----------------------------------------------------------------------------------------------- #


# [ EXIT IF NON-INTERACTIVE SHELL ]-------------------------------------------------------------- #
[[ $- = *i* ]] || return
# ----------------------------------------------------------------------------------------------- #


# ----------------------------------------------------------------------------------------------- #
#                                   START OF INTERACTIVE SECTION
# ----------------------------------------------------------------------------------------------- #

# [ LOAD FUNCTIONS AND MODULES FOR INTERACTIVE SHELLS ]------------------------------------------ #
zmodload zsh/complist zsh/terminfo zsh/zutil zsh/zle
zmodload -m -F zsh/files b:zf_mkdir
autoload -Uz add-zsh-hook compinit is-at-least
# ----------------------------------------------------------------------------------------------- #


# [ SET SHELL OPTIONS ]-------------------------------------------------------------------------- #
IFS=$' \t\n\x00'                                    # Set IFS to space, tab, newline and null.
setopt extended_glob                                # Enable Zsh extended globbing.
setopt interactive_comments                         # Enable comments in interactive shells.
setopt no_beep                                      # Disable beep on errors.
setopt no_correct                                   # Damn you, autocorrect!
[[ $TERM != linux ]] && setopt combining_chars      # Assume the terminal supports combining chars.
                                                    # There are other terminals that don't support
                                                    # combining chars, but I don't use them.

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
SAVEHIST=10000                                      # Number of history entries to save to file.
HISTFILE=/tmp/zsh-$UID/history                      # Set history file.
readonly HISTSIZE SAVEHIST HISTFILE                 # Make the variables readonly.
[[ $OSTYPE = linux-gnu ]] && setopt hist_fcntl_lock # Use fcntl() to lock the history file.
# ----------------------------------------------------------------------------------------------- #


# [ CREATE DIRECTORY FOR ZSH'S HISTORY AND COMPCACHE ]------------------------------------------- #
2>/dev/null zf_mkdir -m 700 /tmp/zsh-$UID
2>/dev/null zf_mkdir -m 700 /tmp/zsh-$UID/zcompcache
# ----------------------------------------------------------------------------------------------- #


# [ AUTO-UPDATE ZSHRC ]-------------------------------------------------------------------------- #
() {
  local update_interval=$(( 2 * 24 * 60 * 60 ))      # Update interval in seconds (2 days).
  local zshrc_mtime=$(zstat +mtime ~/.zshrc)         # Get modification time of /etc/zshrc.
  if (( (zshrc_mtime + update_interval) < $(date '+%s') )) {
    local zshrc_url=https://gitlab.com/kugland/my-zshrc/-/raw/master/zshrc # URL of zshrc.
    print -Pnr $'\e[2K\e[1G%F{green}Updating zshrc\e[0m ...'
    curl -sSL $zshrc_url >/tmp/zsh-$UID/zshrc-new \
      && mv /tmp/zsh-$UID/zshrc-new ~/.zshrc \
      && print -rn -- $'\e[2K\e[1G' \
      && exec zsh                                    # Execute zsh with the same arguments.
  }
}
# ----------------------------------------------------------------------------------------------- #


# [ COLOR SUPPORT ]------------------------------------------------------------------------------ #
# We'll assume that the terminal supports at least 4-bit colors, so we should detect support for
# 8 and 24-bit color. I believe it's also reasonable to assume that a terminal that supports 24-bit
# color will also support 256-color.
[[ $COLORTERM = (24bit|truecolor) ]]; __ZSHRC__color24bit=$(( ! $? ))
((__ZSHRC__color24bit)) || [[ $TERM = *256color* ]]; __ZSHRC__color8bit=$(( ! $? ))
readonly __ZSHRC__color24bit __ZSHRC__color8bit

# If 24-bit color is not supported, and Zsh version is at least 5.7.0, we can use the module
# 'zsh/nearcolor' to approximate 24-bit colors as 8-bit colors. On 4-bit terminals, your mileage
# may vary; on $TERM = linux, for example, the resulting 256-color escapes will result in bright
# white text.
! ((__ZSHRC__color24bit)) && is-at-least 5.7.0 $ZSH_VERSION && zmodload zsh/nearcolor
# ----------------------------------------------------------------------------------------------- #


# [ DETECT SSH SESSIONS ]------------------------------------------------------------------------ #
# First try the easy way: if SSH_CONNECTION is set, we're running under SSH.
__ZSHRC__ssh_session=${${SSH_CONNECTION:+1}:-0}

# If SSH_CONNECTION is not set, then we might be running under sudo, so we check whether we have
# sshd as an ancestor process. This will fail for non-root users if /proc was mounted with
# hidepid=2.
if ! ((__ZSHRC__ssh_session)) {
  __ZSHRC__is_sshd_my_ancestor() {
    local IFS=' '                                   # This is needed to split /proc/<pid>/stat.
    local pid=$$                                    # The current process ID.
    local exe                                       # Basename of the executable.
    while ((pid > 1)) {                             # Continue until we reach the init process.
      pid=${${=${"${:-$(</proc/$pid/stat)}"/*) /}}[2]} # Get the parent process ID.
      exe=${${:-/proc/$pid/exe}:A:t}                # Get the basename of its executable.
      [[ $exe = exe ]] && return 1                  # Path canonicalization fail, return false.
      [[ $exe = sshd ]] && return 0                 # sshd process is our ancestor, return true.
    }
    return 1
  }
  __ZSHRC__is_sshd_my_ancestor && __ZSHRC__ssh_session=1
  unset -f __ZSHRC__is_sshd_my_ancestor
}
readonly __ZSHRC__ssh_session
# ----------------------------------------------------------------------------------------------- #


# [ DETECT PUTTY ]------------------------------------------------------------------------------- #
# Detect if we're running under PuTTY.
[[ $TERM = putty* || $PUTTY = 1 ]]; __ZSHRC__putty=$(( ! $? ))

readonly __ZSHRC__putty
# ----------------------------------------------------------------------------------------------- #


# [ DETECT FSTYPE OF $PWD ]---------------------------------------------------------------------- #
# Cache directory filesystem types.
typeset -gA __ZSHRC__fstypecache
__ZSHRC__fstypecache_hash=""

# Get current directory filesystem type.
# Value is returned in variable REPLY.
__ZSHRC__fstypecache_get() {
  local current_hash=${$(sha256sum /etc/mtab)[1]}   # Hash the contents of /etc/mtab
  if [[ $current_hash != $__ZSHRC__fstypecache_hash ]] { # If the hash has changed,
    __ZSHRC__fstypecache_hash=$current_hash         # Reset the cache.
    __ZSHRC__fstypecache=( )
  }
  if [[ ${__ZSHRC__fstypecache[$PWD]} = "" ]] {     # If value if not found for $PWD, compute it.
    __ZSHRC__fstypecache[$PWD]=$(findmnt -fn -d backward -o FSTYPE --target $PWD)
  }
  REPLY=${__ZSHRC__fstypecache[$PWD]}
}
# ----------------------------------------------------------------------------------------------- #


# [ SEQUENCE TO RESET TERMINAL ]----------------------------------------------------------------- #
__ZSHRC__reset_terminal() {
  stty sane -imaxbel -brkint ixoff iutf8            # Reset terminal settings.
  print -nr $'\e<'                                  # Exit VT52 mode.
  print -nr $'\e7\e[?1049l\e8'                      # Use main screen buffer.
  print -nr $'\e7\e[0;0r\e8'                        # DECSTBM: unset top/bottom margins.
  print -nr $'\e(B\e)B'                             # SCS: set G0 and G1 charsets to US-ASCII.
  [[ $TERM != linux ]] && print -nr $'\e*A\e+A'     # SCS: set G2 and G3 charsets to Latin-1.
  print -nr $'\Co'                                  # Invoke G0 charset as GL
  print -nr $'\e~'                                  # Invoke G1 charset as GR.
  print -nr $'\e%G'                                 # Enable UTF-8 mode.
  print -nr $'\e#5'                                 # DECSWL: single-width line.
  print -nr $'\e[3l'                                # DECCRM: don't show control characters.
  print -nr $'\e[20l'                               # LNM: disable automatic new lines.
  print -nr $'\e[?5l'                               # DECSCNM: disable reverse video.
  print -nr $'\e7\e[?6l\e8'                         # DECOM: disable origin mode.
  print -nr $'\e[?7h'                               # DECAWM: enable auto-wrap mode.
  print -nr $'\e[?8h'                               # DECARM: enable auto-repeat keys.
  print -nr $'\e[?25h'                              # DECTCEM: make cursor visible.
  print -nr $'\e[?2004h'                            # Enable bracketed paste.
  for s ($'\e[?'{9,100{0..6},101{5,6}}'l') {
    print -nr $s                                    # Disable xterm mouse and focus events.
  }
  print -nr ${terminfo[smkx]}                       # DECCKM & DECKPAM: use application mode.

  if [[ $TERM = linux ]] {                          # Color palette for Linux virtual console.
    for idx rgb (
      0 050505  1 cc0000  2 4e9a06  3 c4a000        # Black, red, green, yellow
      4 3465a4  5 75507b  6 06989a  7 a8b3a8        # Blue, magenta, cyan, white
      8 555753  9 ef2929  A 8ae234  B fce94f        # Bri black, bri red, bri green, bri yellow
      C 729fcf  D ad7fa8  E 34e2e2  F ffffff        # Bri blue, bri magenta, bri cyan, bri white
    ) {
      print -nr -- $'\e]P'"${idx}${rgb}"$'\e\\'
    }
  }
}
# ----------------------------------------------------------------------------------------------- #


# [ LOAD LS COLORS ]----------------------------------------------------------------------------- #
# Load colors from ~/.dir_colors or /etc/DIR_COLORS, or use the default colors if they don't exist.
typeset -gxUT LS_COLORS ls_colors ':'
eval $(
  [[ -f ~/.dir_colors ]] && dircolors -b ~/.dir_colors && return
  [[ -f /etc/DIR_COLORS ]] && dircolors -b /etc/DIR_COLORS && return
  dircolors -b
)
# ----------------------------------------------------------------------------------------------- #


# [ SETUP KEYMAP ]------------------------------------------------------------------------------- #
# Only keys used in this script should be listed here.
typeset -A __ZSHRC__keys
__ZSHRC__keys=(
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
  __ZSHRC__keys[CtrlPageUp]=$'\e[5^'
  __ZSHRC__keys[CtrlPageDown]=$'\e[6^'
  __ZSHRC__keys[CtrlDelete]=$'\e[3^'
  __ZSHRC__keys[CtrlRightArrow]=$'\eOc'
  __ZSHRC__keys[CtrlLeftArrow]=$'\eOd'
} elif ((__ZSHRC__putty)) {
  __ZSHRC__keys[Home]=$'\e[1~'
  __ZSHRC__keys[End]=$'\e[4~'
  __ZSHRC__keys[CtrlPageUp]=$'\e\e[5~'              # This is actually Alt+PageUp.
  __ZSHRC__keys[CtrlPageDown]=$'\e\e[6~'            # This is actually Alt+PageDown.
  __ZSHRC__keys[CtrlDelete]=''                      # Sorry, no Ctrl+Delete.
  __ZSHRC__keys[RightArrow]=$'\eOC'
  __ZSHRC__keys[LeftArrow]=$'\eOD'
  __ZSHRC__keys[CtrlRightArrow]=$'\e[C'
  __ZSHRC__keys[CtrlLeftArrow]=$'\e[D'
}

# Bind multiple keys at once.
# $1: Either a key to the __ZSHRC__keys array, or multiple keys sequences separated by spaces.
__ZSHRC__bindkeys() {
  local keys=$1
  local widget=$2
  local IFS=' '                                     # Split keys by spaces.
  for key (${=keys}) {                              # Loop through the key sequences.
    if [[ -n ${__ZSHRC__keys[$key]} ]] {            # If its a key from the __ZSHRC__keys array,
      __ZSHRC__bindkeys "${__ZSHRC__keys[$key]}" $widget # Recurse.
    } else {
      bindkey $key $widget                          # Bind the key to the widget.
    }
  }
}

# Clear the Zsh's keymaps ----------------------------------------------------------------------- #
# Remove keymaps except .safe and main.
bindkey -D command emacs vicmd viins viopp visual

# Remove most key bindings in the main keymap.
bindkey -r '^'{'[','?',{,'[[','[O'}{A,B,C,D},E,F,G,H,I,J,K,L,N,O,P,Q,R,S,T,U,V,W,X,Y,Z}

# Basic keyboard bindings ----------------------------------------------------------------------- #
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
) { for keycode (${=keycodes}) { __ZSHRC__bindkeys $keycode $widget } }

# Send break (Ctrl+D) --------------------------------------------------------------------------- #
# This widget allows Ctrl+D to work even when the buffer is not empty. Pressing Ctrl+D twice on
# an non-empty buffer will close Zsh.
__ZSHRC__send_break() {
  BUFFER+='^D'                                      # Add the ^D to the buffer.
  zle send-break                                    # Send a break, similar to clicking Ctrl+C.
}
zle -N __ZSHRC__send_break
bindkey '^D' __ZSHRC__send_break

# Clear screen (Ctrl+L) ------------------------------------------------------------------------- #
# Zsh's clear-screen doesn't clear the scrollback buffer, this does.
__ZSHRC__clear_screen() {
  print -n $'\e[3J'                                 # Clear the scrollback buffer.
  zle clear-screen                                  # Call zle's clear-screen widget.
}
zle -N __ZSHRC__clear_screen
bindkey '^L' __ZSHRC__clear_screen

# Move to next/previous word (Ctrl+RightArrow / Ctrl + LeftArrow) ------------------------------- #
if [[ $TERM != linux ]] {
  __ZSHRC__backward_word() { local WORDCHARS=${WORDCHARS:s#/#}; zle backward-word }
  __ZSHRC__forward_word() { local WORDCHARS=${WORDCHARS:s#/#}; zle forward-word }

  # Delete next/previous word (Ctrl+Backspace / Ctrl+Delete)
  # Since xterm emits ^H for backspace, backspace won't work. For a workaround,
  # see https://wiki.archlinux.org/title/Xterm#Fix_the_backspace_key
  __ZSHRC__backward_delete_word() { local WORDCHARS=${WORDCHARS:s#/#}; zle backward-delete-word }
  __ZSHRC__forward_delete_word() { local WORDCHARS=${WORDCHARS:s#/#}; zle delete-word }

  # Bind the keys.
  for widget keycode (
    __ZSHRC__backward_word          CtrlLeftArrow
    __ZSHRC__forward_word           CtrlRightArrow
    __ZSHRC__backward_delete_word   CtrlBackspace
    __ZSHRC__forward_delete_word    CtrlDelete
  ) { zle -N $widget && __ZSHRC__bindkeys $keycode $widget }
}

# zle-line-init and zle-line-finish ------------------------------------------------------------ #
# I think I ran into a bug in add-zle-hook-widget, so we are settings the widgets directly.

zle-line-init() {
  ((${+terminfo[smkx]})) && echoti smkx             # Enable application mode
  __ZSHRC__zlelineinit_overwrite                    # Set mode and cursor for overwrite/insert
}

zle-line-finish() {
  ((${+terminfo[rmkx]})) && echoti rmkx             # Disable application mode
}

zle -N zle-line-init
zle -N zle-line-finish

# Insert and overwrite mode --------------------------------------------------------------------- #
__ZSHRC__overwrite_state=0                          # Overwrite mode state, 0 = off, 1 = on
__ZSHRC__overwrite_prompt=''                        # Overwrite mode indicator for RPROMPT

# Sets cursor shape according to insert/overwrite state and update the indicator.
__ZSHRC__cursorshape_overwrite() {
  if ((__ZSHRC__overwrite_state)) {                 # In overwrite mode:
    print -n $'\e[?6c'                              # █ cursor on $TERM = linux
    print -n $'\e[3 q'                              # _ cursor on xterm and compatible
  } else {                                          # In insert mode:
    print -n $'\e[?2c'                              # _ cursor on $TERM = linux
    print -n $'\e[5 q'                              # | cursor on xterm and compatible
  }
}

# Update the overwrite mode indicator.
__ZSHRC__indicator_overwrite() {
  local overwrite_indicator
  zstyle -s ':myzshrc:prompt' overwrite-indicator overwrite_indicator
  ((__ZSHRC__overwrite_state)) \
    && __ZSHRC__overwrite_prompt='  '$overwrite_indicator \
    || __ZSHRC__overwrite_prompt=''
}

# Handler for the 'Insert' key.
__ZSHRC__keyhandler_overwrite() {
  zle overwrite-mode                                # Toggle overwrite mode.
  [[ $ZLE_STATE = *insert* ]]
  __ZSHRC__overwrite_state=$?                       # Save the overwrite mode state.
  __ZSHRC__cursorshape_overwrite                    # Update the cursor shape.
  __ZSHRC__indicator_overwrite                      # Update the indicator.
  # If we're not in the start context, we can't reset the prompt, as it -- for some reasom --
  # will mess up the RPROMPT.
  [[ $CONTEXT = start ]] && zle reset-prompt        # Reset the prompt.
}
zle -N __ZSHRC__keyhandler_overwrite
__ZSHRC__bindkeys Insert __ZSHRC__keyhandler_overwrite

__ZSHRC__zlelineinit_overwrite() {
  # Since zle's overwrite mode is not persistent, we need to restore the state on each prompt.
  ((__ZSHRC__overwrite_state)) && zle overwrite-mode
  __ZSHRC__cursorshape_overwrite
}

zle -N zle-line-init

__ZSHRC__preexec_overwrite() {
  # Always reset to insert cursor before running commands.
  print -n $'\e[?2c'                                # _ cursor on $TERM = linux
  print -n $'\e[5 q'                                # │ cursor on xterm and compatible
}

add-zsh-hook preexec __ZSHRC__preexec_overwrite


# [ PROMPT SETUP ]------------------------------------------------------------------------------- #
# That's the way I like it.

myzshrc_prompt_precmd() {
  __ZSHRC__reset_terminal

  local before_userhost before_path after_path \
        ssh_indicator overwrite_indicator jobs_indicator error_indicator \
        continuation eol_mark gitstatus_prompt

  zstyle -s ':myzshrc:prompt' before-userhost before_userhost
  zstyle -s ':myzshrc:prompt' before-path before_path
  zstyle -s ':myzshrc:prompt' after-path after_path
  zstyle -s ':myzshrc:prompt' ssh-indicator ssh_indicator
  zstyle -s ':myzshrc:prompt' overwrite-indicator overwrite_indicator
  zstyle -s ':myzshrc:prompt' jobs-indicator jobs_indicator
  zstyle -s ':myzshrc:prompt' error-indicator error_indicator
  zstyle -s ':myzshrc:prompt' continuation continuation
  zstyle -s ':myzshrc:prompt' eol-mark eol_mark

  __ZSHRC__gitstatus_prompt_update

  ((__ZSHRC__ssh_session)) && PS1=$ssh_indicator || PS1=''
  PS1+="${before_userhost}%(!..%n@)%m${before_path}%~${after_path}"

  RPROMPT="\${__ZSHRC__overwrite_prompt}"
  RPROMPT+="%(1j.  $jobs_indicator.)"
  RPROMPT+="%(0?..  $error_indicator)"
  RPROMPT+=$gitstatus_prompt

  PS2=''; for level ({1..16}) { PS2+="%(${level}_.${continuation}.)" }; PS2+=' '

  # RPS2 will be type of the current open block (if, while, for, etc.)
  # Make RPS2 show [cont] when we're in a continuation line (the previous line ended with '\').
  RPS2='%B%F{black}[%f%b${${(%):-%^}//(#s)(#e)/cont}%B%F{black}]%f%b'

  PROMPT_EOL_MARK=${eol_mark}
}

add-zsh-hook precmd myzshrc_prompt_precmd

# Window title ---------------------------------------------------------------------------------- #
__ZSHRC__ellipsized_path_window_title() {
  local cwd=${(%):-%~}                              # Current working directory.
  if (( ${#cwd} > 40 )) {                           # If it's too long,
    local cwd_array=(${(s:/:)${cwd}})               # Split the path into an array.
    local i
    for i ({1..${#cwd_array}}) {                    # Loop through each path element.
      local elm=${cwd_array[$i]}
      if (( ${#elm} > 18 )) {                       # Make sure each element is at most 18 chars.
        cwd_array[$i]=${elm[1,18]}…                 # If not, truncate and add an ellipsis.
      }
    }
    cwd=${(j:/:)cwd_array}                          # Join the array back into a path.
    if (( ${#cwd_array} >= 3 )) {                   # If there's at least 3 elements,
      cwd=${${cwd[1,20]}%/*}/…/${${cwd[-20,-1]}#*/} # Join the head and the tail with an ellipsis.
    }
    if [[ ${cwd[1]} != '~' ]] { cwd=/${cwd} }       # Prefix with '/' if it doesn't start with '~'.
  }
  print -n $cwd                                     # Print the path.
}

__ZSHRC__print_window_title() {
  local cwd=$(__ZSHRC__ellipsized_path_window_title) # Get the current directory (ellipsized).
  local cmd=$1                                      # Get the command name.
  cwd=${cwd//[[:cntrl:]]/ }                         # Strip control characters from the path.
  cmd=${cmd//[[:cntrl:]]/ }                         # Strip control characters from the commmand.
  print -n $'\e]0;'                                 # Start the title escape sequence.
  ((__ZSHRC__ssh_session)) && print -n '🌎'         # Show we're running through SSH.
  ((UID==0)) && print -n '🔴'                       # Add a red circle emoji if the user is root.
  ((__ZSHRC__ssh_session)) && print -Pn ' [%m]'     # Show the SSH hostname.
  ((UID==0||__ZSHRC__ssh_session)) && print -n ' '  # Add a space if we're root or SSH.
  print -nr -- $cwd                                 # Print the path.
  print -n ' • '                                    # Add a separator.
  print -nr -- $cmd                                 # Print the command name.
  print -n $'\e\\'                                  # End the title escape sequence.
}

__ZSHRC__precmd_window_title() {                    # After the command is run, we're back in zsh,
  __ZSHRC__print_window_title zsh                   # so let the window name reflect that.
}

__ZSHRC__preexec_window_title() {
  local cmd=$2
  [[ ${#cmd} -gt 32 ]] && cmd="${cmd[1,31]}…"       # Truncate the command line if it's too long.
  __ZSHRC__print_window_title ${cmd}                # Show the command name in the window title.
}

add-zsh-hook precmd __ZSHRC__precmd_window_title
add-zsh-hook preexec __ZSHRC__preexec_window_title

# Show git status in RPROMPT -------------------------------------------------------------------- #
# On Arch Linux, install the gitstatus, gitstatus-bin or gitstatus-git packages from AUR.
# For other distros, cf. https://github.com/romkatv/gitstatus.
if [[ -n ${commands[git]} && -r /usr/share/gitstatus/gitstatus.plugin.zsh ]] {
  source /usr/share/gitstatus/gitstatus.plugin.zsh

  # Sets GITSTATUS_PROMPT to reflect the state of the current git repository.
  function __ZSHRC__gitstatus_prompt_update() {
    gitstatus_prompt=''                             # Reset git status prompt.

    __ZSHRC__fstypecache_get                        # Get the filesystem type of the current dir.
    if [[ $REPLY = (automount|fuse.sshfs|nfs) ]] {  # If it's a network filesystem,
      return                                        # don't try to get git status.
    }

    # Call gitstatus_query synchronously. Note that gitstatus_query can also be
    # called asynchronously; see documentation in gitstatus.plugin.zsh.
    gitstatus_query 'MY'                  || return 1  # error
    [[ $VCS_STATUS_RESULT == 'ok-sync' ]] || return 0  # not a git repo

    local git_prefix stash_count staged_count unstaged_count untracked_count commits_behind \
          commits_ahead push_commits_behind push_commits_ahead action num_conflicted

    zstyle -s ':myzshrc:gitstatus' git-prefix git_prefix
    zstyle -s ':myzshrc:gitstatus' stash-count stash_count
    zstyle -s ':myzshrc:gitstatus' staged-count staged_count
    zstyle -s ':myzshrc:gitstatus' unstaged-count unstaged_count
    zstyle -s ':myzshrc:gitstatus' untracked-count untracked_count
    zstyle -s ':myzshrc:gitstatus' commits-ahead commits_ahead
    zstyle -s ':myzshrc:gitstatus' commits-behind commits_behind
    zstyle -s ':myzshrc:gitstatus' push-commits-ahead push_commits_ahead
    zstyle -s ':myzshrc:gitstatus' push-commits-behind push_commits_behind
    zstyle -s ':myzshrc:gitstatus' action action
    zstyle -s ':myzshrc:gitstatus' num-conflicted num_conflicted

    local p="  ${git_prefix} "                      # Git status prefix
    local where                                     # Branch name, tag or commit
    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]] {
      where=$VCS_STATUS_LOCAL_BRANCH                # Use local branch name, e.g. 'master'.
    } elif [[ -n $VCS_STATUS_TAG ]] {
      p+='%F{black}%B#%b%f'                         # Add # to signify a tag.
      where=$VCS_STATUS_TAG                         # Use tag name, e.g. '#v1.0.0'.
    } else {
      p+='%F{black}%B@%b%f'                         # Add @ to signify a commit.
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

  # Start gitstatusd instance with name "MY". The same name is passed to gitstatus_query in
  # __ZSHRC__gitstatus_prompt_update. The flags with -1 as values enable staged, unstaged,
  # conflicted and untracked counters.
  gitstatus_stop 'MY' && gitstatus_start -s -1 -u -1 -c -1 -d -1 'MY'
} else {
  __ZSHRC__gitstatus_prompt_update() {
    gitstatus_prompt=""
  }
}

# Simple prompt and fancy prompt ---------------------------------------------------------------- #
# A simple prompt that will work nicely in a console with limited charset and only 16 colors,
# such as the Linux console.
__ZSHRC__simple_prompt() {
  zstyle ':myzshrc:prompt' before-userhost '%B%F{%(!.1.2)}'
  zstyle ':myzshrc:prompt' before-path '%f%b:%B%4F'
  zstyle ':myzshrc:prompt' after-path '%f%b%# '
  zstyle ':myzshrc:prompt' ssh-indicator '%B%0F[%f%bssh%B%0F]%f%b '
  zstyle ':myzshrc:prompt' overwrite-indicator '%K{4}%B%7F over %f%b%k'
  zstyle ':myzshrc:prompt' jobs-indicator '%K{5}%B%7F %j job%(2j.s.) %f%b%k'
  zstyle ':myzshrc:prompt' error-indicator '%K{1}%B%7F %? %f%b%k'
  zstyle ':myzshrc:prompt' continuation '%B%0F» %f%b'
  zstyle ':myzshrc:prompt' eol-mark '%B%0F·%f%b'
  zstyle ':myzshrc:gitstatus' git-prefix '%B%1Fgit%f%b'
  zstyle ':myzshrc:gitstatus' stash-count '%B%0F*'
  zstyle ':myzshrc:gitstatus' staged-count '%B%2F+'
  zstyle ':myzshrc:gitstatus' unstaged-count '%B%1F+'
  zstyle ':myzshrc:gitstatus' untracked-count '%B%1F*'
  zstyle ':myzshrc:gitstatus' commits-ahead '%6F%B↑'
  zstyle ':myzshrc:gitstatus' commits-behind '%6F%B↓'
  zstyle ':myzshrc:gitstatus' push-commits-ahead '%6F%B←'
  zstyle ':myzshrc:gitstatus' push-commits-behind '%6F%B→'
  zstyle ':myzshrc:gitstatus' action '%B%1F'
  zstyle ':myzshrc:gitstatus' num-conflicted '%1F!%B'
  __ZSHRC__indicator_overwrite                      # Update the overwrite indicator if needed.
}

# Completely unnecessary, but I like it.
# This prompt requires Nerd Fonts (https://www.nerdfonts.com/).
__ZSHRC__fancy_prompt() {
  # For the main prompt.
  local userhost_color='%(!.#b24742.#47a730)'
  zstyle ':myzshrc:prompt' before-userhost "%K{$userhost_color}%B%7F "
  zstyle ':myzshrc:prompt' before-path '%b%F{'$userhost_color$'}%K{#547bb5}\uE0B4 %B%7F'
  zstyle ':myzshrc:prompt' after-path '%b%F{#547bb5}%K{'$userhost_color$'}\uE0B4%k%F{'$userhost_color$'}\uE0B4%f '
  zstyle ':myzshrc:prompt' ssh-indicator $'%K{238}%15F ssh %K{'$userhost_color$'}'
  zstyle ':myzshrc:prompt' overwrite-indicator $'%4F\uE0B6%K{4}%B%7Fover%k%b%4F\uE0B4%f'
  zstyle ':myzshrc:prompt' jobs-indicator $'%5F\uE0B6%K{5}%B%7F%j job%(2j.s.)%k%b%5F\uE0B4%f'
  zstyle ':myzshrc:prompt' error-indicator $'%1F\uE0B6%K{1}%B%7F%?%k%b%1F\uE0B4%f'
  zstyle ':myzshrc:prompt' continuation $'%B%0F\uf054%f%b'
  zstyle ':myzshrc:prompt' eol-mark '%B%0Fﱢ%b%f'
  zstyle ':myzshrc:gitstatus' git-prefix '%B%208F%f%b'
  zstyle ':myzshrc:gitstatus' stash-count $'%245F\uf4a6%B%250F'
  zstyle ':myzshrc:gitstatus' staged-count '%106F%B%154F'
  zstyle ':myzshrc:gitstatus' unstaged-count '%167F%B%210F'
  zstyle ':myzshrc:gitstatus' untracked-count $'%167F\uf005%B%210F'
  zstyle ':myzshrc:gitstatus' commits-ahead '%36Fﰵ%B%86F'
  zstyle ':myzshrc:gitstatus' commits-behind '%36Fﰬ%B%86F'
  zstyle ':myzshrc:gitstatus' push-commits-ahead '%36Fﰯ%B%86F'
  zstyle ':myzshrc:gitstatus' push-commits-behind '%36Fﰲ%B%86F'
  zstyle ':myzshrc:gitstatus' action '%B%210F'
  zstyle ':myzshrc:gitstatus' num-conflicted '%167F%B%210F'
  __ZSHRC__indicator_overwrite                      # Update the overwrite indicator if needed.
}

# Select the prompt.
# The fancy prompt will be used if the terminal is a virtual TTY, X11 is available, we're using
# a UTF-8 locale, we're not in a SSH session, and the terminal supports 8-bit colors; otherwise
# the simple prompt will be used.
[[ $TTY = /dev/pts/* ]] \
  && [[ $LANG = *UTF-8* ]] \
  && ! ((__ZSHRC__ssh_session)) \
  && ((__ZSHRC__color8bit)) \
  && __ZSHRC__fancy_prompt || __ZSHRC__simple_prompt
# ----------------------------------------------------------------------------------------------- #


# [ COMPLETION SETUP ] -------------------------------------------------------------------------- #
compinit -d /tmp/zsh-$UID/zcompcache/zcompdump
bindkey -r '^X'{'^R','?',C,a,c,d,e,h,m,n,t,'~'} '^['{',',/,'~'}
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path /tmp/zsh-$UID/zcompcache
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
zstyle ':completion:*:processes-names' command "ps -eo exe= | sed -e 's,^.*/,,g' | sort -f | uniq"
zstyle ':completion:*:processes-names' list-colors '=*=01;32'

# ssh, scp, sftp and sshfs -----------------------------------------------------------------------#
# Load ssh hosts from ~/.ssh/config
() {
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
  [[ -n ${commands[sshfs]} ]] && function() _user_at_host() { _ssh_hosts "$@" }
  # Don't complete hosts from /etc/hosts
  zstyle -e ':completion:*' hosts 'reply=()'
}

# Hide entries from completion ------------------------------------------------------------------ #
zstyle ':completion:*:parameters' ignored-patterns \
  '(_*|(chpwd|periodic|precmd|preexec|zshaddhistory|zshexit)_functions|PERIOD)'
zstyle ':completion:*:functions' ignored-patterns \
  '(_*|pre(cmd|exec)|TRAP*)'
zstyle ':completion:*' single-ignored show
# ----------------------------------------------------------------------------------------------- #


# [ EXIT MESSAGE ]------------------------------------------------------------------------------- #
# Print a message when exiting the shell.
__ZSHRC__zshexit_exit_message() {
  print -P "%B%F{black}-----%f zsh%b (%B%F{yellow}$$%f%b) %Bfinished %F{black}-----%f%b"
}
add-zsh-hook zshexit __ZSHRC__zshexit_exit_message
# ----------------------------------------------------------------------------------------------- #


# [ COMMANDS ]----------------------------------------------------------------------------------- #
# Functions and aliases.

# nmed - use vared to rename a file ------------------------------------------------------------- #
nmed() {
  local old=$1
  local new=$1
  if [[ -e $old ]] {
    print -Pn '%B%F{cyan}Old name%b:%f %B'
    print -r -- $old
    vared -e -p '%B%F{cyan}New name%b:%f %B' new \
      && print -Pn '%b' && mv -i -v -- $old $new
  } else {
    >&2 print -r "nmed: \`$old': File not found."
  }
}

# Customize and colorize some commands ---------------------------------------------------------- #
# Set the default flags for ls:
#   -h: human readable sizes (e.g. 1K 2M 4G)
#   --color=auto: use colors when output is a terminal
#   --indicator-style=slash: use a slash to indicate directories
#   --time-style=long-iso: show times in long ISO format (e.g. 2017-01-01 12:00)
alias ls='command ls -h --color=auto --indicator-style=slash --time-style=long-iso'
() {
  local g
  for g ({{,bz,lz,zstd,xz}{,e,f},pcre{,2}}grep) {   # Add colors to grep and friends.
    [[ -n ${commands[$g]} ]] && alias "$g=command $g --color=auto"
  }
}

alias diff='command diff --color=auto'              # Add colors to diff command.
alias ip='command ip --color=auto'                  # Add colors to ip command.
# ----------------------------------------------------------------------------------------------- #


# [ LOAD PLUGINS ]------------------------------------------------------------------------------- #
# Download and load plugins.

# Functions for (down)loading plugins ----------------------------------------------------------- #
# Check sha256sum of multiple files.
# Parameters:
#   $1: plugin name
#   $3: file name
#   $4: sha256 hash
#   $5: file name
#   $6: sha256 hash
#   ...: possibly more files
__ZSHRC__deps_check_sha256sum() {
  local name=$1
  shift 1
  local file sha256
  for file sha256 ("$@") {
    print -r "$sha256  $HOME/.zshrc-deps/$name/$file"
  } | >/dev/null 2>&1 sha256sum -c --quiet -
}

# Download a plugin and install it.
# Parameters:
#   $1: plugin name
#   $2: plugin base url
#   $3: file name
#   $4: sha256 hash
#   $5: file name
#   $6: sha256 hash
#   ...: possibly more files
__ZSHRC__deps_fetch() {
  local name=$1
  local baseurl=$2
  shift 2
  local file sha256
  if [[ -d "$HOME/.zshrc-deps/$name" ]] {
    __ZSHRC__deps_check_sha256sum "$name" "$@" && return 0
  }
  local curl_args=( -sSL --create-dirs )
  for file sha256 ("$@") {
    curl_args+=( -o "$HOME/.zshrc-deps/$name/$file" "$baseurl/$file" )
  }
  print -Pnr $'\e[2K\e[1G%B%0F[%b%fzshrc%B%0F]%b%f %F{green}Fetching dependency \e[0;4m$name\e[0m ...'
  curl "${curl_args[@]}"
  print -rn $'\e[2K\e[1G'
  __ZSHRC__deps_check_sha256sum "$name" "$@" || {
    rm -rf "$HOME/.zshrc-deps/$name"
    return 1
  }
}

# zsh syntax highlighting ----------------------------------------------------------------------- #
__ZSHRC__deps_fetch \
  zsh-syntax-highlighting \
  https://raw.githubusercontent.com/zsh-users/zsh-syntax-highlighting/0.7.1 \
  zsh-syntax-highlighting.zsh \
  b597811f7f6c1169d45d4820d3a3dcfc5053ceefb8f88c5b0f4562f500499884 \
  zsh-syntax-highlighting.plugin.zsh \
  a2958aeb49a964e0831c879c909db446da59a01d3ae404576050753a08eeeeec \
  highlighters/brackets/brackets-highlighter.zsh \
  55f8002d07d78edbf33a918c176eee8079b81aaadc1efdfd75f29c872befc56c \
  highlighters/cursor/cursor-highlighter.zsh \
  bd6ef3aae900fee57ff132360b3dd9d68df5aab150a33e32259fd5adbe8efd49 \
  highlighters/line/line-highlighter.zsh \
  1a12c094770bc00276395dc71a398a63fd768c433453d35f4e47e5d315dfacf0 \
  highlighters/main/main-highlighter.zsh \
  f72e9c2b8c91bb239295e4e2e02f756086276a021e72fc03de98e61c62b6e39a \
  highlighters/pattern/pattern-highlighter.zsh \
  29fa6c332f1a1c81218041fd9704becba0fc01b455c3e342e06b7edae3e567e3 \
  highlighters/root/root-highlighter.zsh \
  7a038444d4cd60f9eaf07993b6a14d0055ad8706e09a32780cb65ea0a90530ee \
  .version \
  902311c7bb38fa1658ff403def6158ee7378fe9d6e2e284fa1c38735c31bd30b \
  .revision-hash \
  2070743a71dbdccd323f1848e8f9f1fd893081c4e779f9f5a3cebcee6b2e467d \
  && {
    source ~/.zshrc-deps/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh

    # Disable syntax highlighting when under network directories.
    if [[ -n $ZSH_HIGHLIGHT_VERSION ]] {
      __ZSHRC__precmd_disable_syntax_highlight_on_netfs() {
        __ZSHRC__fstypecache_get                    # Get the filesystem type of the cur dir.
        if [[ $REPLY = (automount|fuse.sshfs|nfs) ]] {  # Check if it's a network filesystem.
          ZSH_HIGHLIGHT_MAXLENGTH=0                 # Disable syntax highlight if it is.
        } else {
          unset ZSH_HIGHLIGHT_MAXLENGTH             # Enable it otherwise.
        }
      }
    }
    add-zsh-hook precmd __ZSHRC__precmd_disable_syntax_highlight_on_netfs
  }

# zsh history substring search ------------------------------------------------------------------ #
__ZSHRC__deps_fetch \
  zsh-history-substring-search \
  https://raw.githubusercontent.com/zsh-users/zsh-history-substring-search/4abed97b6e67eb5590b39bcd59080aa23192f25d \
  zsh-history-substring-search.plugin.zsh \
  edceeaa69a05796201aa064c549a85bc4961cc676efcf9c94c02ec0a4867542b \
  zsh-history-substring-search.zsh \
  9365d9919e8cbb77f4a26c39f02434f3a46d0777bda0ef3fa2f585d95999c7bd \
  && {
    source ~/.zshrc-deps/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh

    # Bind Ctrl+PageUp and Ctrl+PageDown to history-substring-search-{up,down}.
    __ZSHRC__bindkeys CtrlPageUp history-substring-search-up
    __ZSHRC__bindkeys CtrlPageDown history-substring-search-down
  }

# zsh completions ------------------------------------------------------------------------------- #
__ZSHRC__deps_fetch \
  zsh-completions \
  https://raw.githubusercontent.com/zsh-users/zsh-completions/0.34.0/ \
  zsh-completions.plugin.zsh \
  87ff385996ff4f662c736beaee6e366f609e2fba536c331709208f09f35469b1 \
  src/_afew \
  af4adfb22ae42dcb33b2b2f6c61e76c8b3b2b6c22d8dd98a8eb1eb595470a73e \
  src/_android \
  36d52303d4f78c68a917a08c72f4846114425f9fb3a45c7220492e5815c8c485 \
  src/_archlinux-java \
  456fd7ae4bf80079dc0bb8bb5b8ebf80b25f95ff4164be86d047855c5866a183 \
  src/_artisan \
  adceb6d65917d0574fdeace8a5be906d89f6134e30fc609b5cbbbd4dff146770 \
  src/_atach \
  be0cb2adf6c6ee91c7e75ab8b5c7ebf2cc1663d1f4c5fb1d5e387d29df979a30 \
  src/_bitcoin-cli \
  1a81e50ff8072afcd46c4ea791f127b0d1e0b6460cfec94ec84c8d135216cf8f \
  src/_bower \
  349005e6baee4dfd7ace62ebe04ff2b3946b28d3308d5e299904df478e0e7971 \
  src/_bundle \
  03a11fa79d0c34cf63bfe144873d4f08f8e7a35d13096362fccbd2d7ac8f1d36 \
  src/_caffeinate \
  41c3eccb88f526e97b88f4312fa90dade9bea0b511bb9b0028dfb24e7fc0145e \
  src/_cap \
  36411d1977a9aae72d1946ef044c2c17b3c7de7cbd0aeda7dfa3803e50505884 \
  src/_cask \
  04d843a4875d0fddccbd4c08f7ca13b7822f7a26fd87f5e587373873e17c20e2 \
  src/_ccache \
  b2e3a143bdb9f017656dae14b649a0f130e4ff58fda7ac0a2a6bae2731155da8 \
  src/_cf \
  4902b0ed28af23ecab30bbbbe5250bce0ad574930946ed9cbd62c6dacf4fd44d \
  src/_choc \
  442da7248afead3dd541a668ae01039f4de0b45aca1081951bbc6f58303a8e4e \
  src/_chromium \
  0afe883662d3c71be71572f55455ef134c72f596249289b060d8ac5c589cfa1c \
  src/_cmake \
  92066ab5c199d9eebf14e4d9015788d48f42ff08ac5583ffdc132f63822cefd3 \
  src/_coffee \
  246ff5b991d499a3fcfff77ecc283b020922d9e5a2c46d9337990c7fefebbc71 \
  src/_composer \
  b4bcfb3bcae67c0c2ccee62535ec1f24dd78a621b8cbaff6767698e38308efa8 \
  src/_conan \
  dc8f425e930e85779318a1f3a2fbd51b45642b499ccf6551ce5310cfea16a2a3 \
  src/_concourse \
  685d616874c538d3d6c1f1b4e97a1f5a5696e510855857a6a8c3911e67b8a24f \
  src/_console \
  03e686a3679fbc2e1127136f5e13784d3d62a77e1f0eb30af7dca169d8ed2307 \
  src/_cppcheck \
  489b6cdd7114f614ef1b83abe9265fde3089d80c9b3a53f279c1725dfce76ca5 \
  src/_dad \
  f64ac01126d6ddcfc9a8f8b336197ed22cd043d2be7e98d7efdb86787620c1a3 \
  src/_debuild \
  1b685fe44df82dcc8a984c47361129482de4b839a3e09d880660fa0034a1c05a \
  src/_dget \
  c7d0b55ecf1db58e90b56265a0e59d6550de0496ae40645fb976ed6e4c130d51 \
  src/_dhcpcd \
  05e3af0e2582099e8d884e06def71021f57e3761c805541488ec9d41c8d04bcd \
  src/_diana \
  f54e8fc70aa5116bad2fb92ec3cb586f17f10fdc9b96672bcb849ea496744ba5 \
  src/_docpad \
  3822082256bbd2b30e498e0df28f9f7b9890265f967d0fe5e38d37dd6078bbb7 \
  src/_drush \
  c2a8a7c71aa8a19c46d6f56d423564f04a614a7942579ae7dd971fbaedb33639 \
  src/_ecdsautil \
  92cafe48fd33474c9519b3e03c994ac9da56fa9c53e8f5586656649f84eb5cd0 \
  src/_emulator \
  77ef5a4e3ab5ce09c94c6c9ece02c373c1068b0751ace366cb1092e908a6e2ce \
  src/_envdir \
  95d6fb1e292ccccf5700ece962d58010525829ef3916d3c878c7c75851634b25 \
  src/_exportfs \
  9749151c3b1490c7e55a01868ea1b14a22dc2d9e8ec4c83eab5309db8f3d3593 \
  src/_fab \
  20fb9db8fa10f50207bb2bf5bd39f01c74cdda283553d244739369f23c350c08 \
  src/_fail2ban-client \
  240d25faf9ec6e271e8be64514381d4d398108418889041c5b600b9318df4392 \
  src/_ffind \
  ca2b6e344035df7d960ae2d5c291536aa1f95c83c0ff1690f9ec7dad0986dfab \
  src/_fleetctl \
  dacd8cdf6177b643ef14bda41e95f032799490f0e01790a0d9d4455409db8349 \
  src/_flutter \
  6571276df4378b60204d691d52f15482972f1c1da4ca6ef4da0b1810fd11cdde \
  src/_force \
  e71d22cd1049858362fca3e6aa7f7cfee96e47d3d20cb14c8b017a478ae38ce7 \
  src/_fwupdmgr \
  6db1896930f9ae9a2e1e8cf8a70f4ea1379c13079aa002814fa7e018700c673b \
  src/_gas \
  c2f0df5609acd6e1f37c7eb65b380824e1ec9a8356978551fc0c695e765d52c2 \
  src/_ghc \
  b6ac235887383c707f493b094f1e33ab6ecce5e927038de013ce2adaa9874b2b \
  src/_gist \
  95af9325313e57ee1a7601fc0251c10ecd232ecfb0868109253faefd269fc16b \
  src/_git-flow \
  ba38944491dc09efb3e8d82a1e74bb20927feb2972ca1c4edd485c0ac23d529d \
  src/_git-journal \
  a4ebafff567dcc8015747dfbc1aab133fecd9e14ad7934622c476fae48bfd27c \
  src/_git-pulls \
  8bea8f62b5a8a2ace566b357c93106110106113701e16b2caf2ae966c03bc95f \
  src/_git-revise \
  aa0a52a0f66bb12144859384119140b1cdf1a8943cbd2474eb33d90cd8baf654 \
  src/_git-wtf \
  bdce5075d134488b71a45cb5179ccf6c6861e885edec2e63c6e55a63b6daf043 \
  src/_glances \
  76e0f8d6311120f87d02852600fe15d31248b46f5ee533c1c959c87f8e0da8b0 \
  src/_golang \
  a1af2f187b8e4cb4b66cc500884666f1763df74e3e6b50378725b8c2c871ce3d \
  src/_google \
  223c718b4c4bd81f34d3360f9bbd7d2b9dd6583c2c214a34cdd17ae9b0aacbf9 \
  src/_gpgconf \
  25f3d896bd1702860f0f5b0858dc49fa8ff1a4ad956c9fb48a56c3f1a2811147 \
  src/_gtk-launch \
  906bb0b3e8c9e8b64d39ace6d7db4b30e3aac810ee03d20688f287d77120c799 \
  src/_hello \
  6cf6a91ed4d49b03a4c402aa798395885092f0a5b21f703289b30637d6b9f387 \
  src/_hledger \
  b0f0f535ccfb6ddef1fa49f8254d820fad6eaa5fb25c7df64a83125c95782c07 \
  src/_homestead \
  35ed3342280028c7108be1359946cdfb8c5ed0da7e09e1c88a51e3a486b6a385 \
  src/_httpie \
  fe9cc98718303db0a6e64092ef2388f2487d372e5821ac4f00aea1da8207405a \
  src/_ibus \
  a3449bd26eb2d03d28d5a1a1960ac0dfc8051da0ad90548b60d64d11e006d50a \
  src/_include-what-you-use \
  ce48aa5543fb646f3948a8c9c7dfb1ce9669ff43da7040c1c93a6c1a49a9cc3b \
  src/_inxi \
  35376fc84a835e710d5d6c3399b48e19d3550da8e7f59f969b8445086fdc3b7e \
  src/_jmeter \
  982e66ef8a4a87c3c50797b650e4ce78591eeac0e43ca27f6d25cc48a270ae72 \
  src/_jmeter-plugins \
  4103629d57fc9412cdad58317853a18764659df64702dcfafe1ea3e98aef575f \
  src/_jonas \
  7b5692a0ab1356ac13e6e1a9737d2ec4beab1c987e14cfb03bc2b88c414b7dae \
  src/_jrnl \
  5daf2d172131da65177eb487fcfc4d564592782b0cbe95341b902a0141c77708 \
  src/_kak \
  4a0039161cef20c1866ad1c0429410efa0ea3d56af5d7685656ae2f6c599cf9e \
  src/_kitchen \
  7f692cea67a2b58b88e9ba0b0efe435b026af368a7942c11aa57413514af7868 \
  src/_knife \
  fdc539de46503825293d2caba6bc07de3df9512d207346b119a37009cea69002 \
  src/_language_codes \
  5408c78863302e5f40d160a0ced0d8b057a89ba16cbade08094058b76996926f \
  src/_lilypond \
  f87b6080aed143304d4eff9413cfc6ca43b879c3a475641ef7fc39a7328aede5 \
  src/_lunchy \
  054b6aa09bbb162bf409c7d6c5d03270288f2c165300807ac369dd64ed058170 \
  src/_mc \
  3ae238e7a8bca1f1dcda0300a46ea16869ebf044a8c50f8b6343f090c5da333a \
  src/_middleman \
  3241b31b3cfdf4328a07b09978f2b151cecf7b580617a680e7770ff05c9f91c5 \
  src/_mina \
  fddf0ce5cc74bd2a162cd286fb38f81566173fec5e728c60c7c8bf1088cb0e2c \
  src/_mix \
  959eedcd209227cc90e3f7887acd28d1bd392da5107896ffbc80ffdfdc7f08bf \
  src/_mssh \
  4da67100d30c03d67b895ae21ebcfa13316ca43be8ff5071cb5ec9467e3c3615 \
  src/_mussh \
  9ce16a80fa01dac0a9dc8c95e1efef9bffa0381e562f76ca757cbcfdf2411260 \
  src/_mvn \
  3e653b686626502c792487a1bbec55d4496be3f13cbf2b4050062351281e09bd \
  src/_nano \
  7f422f6e784dd9ac9b1d46ad90da89d0e065aedd75c7595ab6a726fee70d8bd2 \
  src/_nanoc \
  cb1dd4ffccd2657aa9668e4b515a2e8e5f3b5e899a76e0d24d31613df94791c1 \
  src/_nftables \
  963b34ca3662759bab90d3e1d592ca5c315c9bf4d16a07caa274edc01b4011ee \
  src/_node \
  21e7cac91e4150c67a658b0d150a2b92ff84e0f5a488075a6c147f8f0868b96a \
  src/_nvm \
  2fe4f89aafb45c0854f410c12a1a0a2c5908547aa125027c17f4cc6d0115c4c4 \
  src/_openssl \
  45678cf7306065df25e47ad37d533a034a17b7761de839d330b57bd5f6760b60 \
  src/_openvpn3 \
  3385267f29d735843fc12452f261bb70b3c304d42cbc887da548b9be9338272e \
  src/_optirun \
  ed1435179d74a0d47f7ac31a22e29b9dfba644e221d4584fe7eb825af8d10ffa \
  src/_opustools \
  4c227abd8e98ce2b014e827ad8e3e3dc638fce618334c1d3257bc3dc6e346ae7 \
  src/_patool \
  44a3e917e58d112ef88f7f587530fdab8fc917cfe3c6a8e97a36b803d2f87d99 \
  src/_perf \
  9691a0111fc0e4883aa0482216da0f6e2c9b44c2bf7f6bb3e05cb831f7f1546a \
  src/_periscope \
  b3a33e6ec31ffe3fa5c24fd64a03e198a2ca78bfbf6a73e7370cfc195c957f16 \
  src/_pgsql_utils \
  f68a64cf91e508d76e0d669ddf71adc7a48770d7028c12b98e3358bdf975222d \
  src/_phing \
  cda6822c7c340080d8dbdc2bb024c556174f0afa76b4c1c42e2acd146f9c02fe \
  src/_pixz \
  e160c8908392b92596b454ceec16f74b005c4c1ce6c03692eef6578e08c1cadf \
  src/_pkcon \
  129cdf266a2287c88800b029f1a1d46994c1394ebb67d1f9b0cb949871c064c5 \
  src/_play \
  bd8c26f29f38fd5e82e05a6f139ea8a5ca2bc87f75fae6f0581b4223498ff09d \
  src/_pm2 \
  cd0ccacc67db22aae19b122b3053e37d8b9d3ba4b5000cd071cf41945cb8100d \
  src/_port \
  a06d7c72dd8b97631d0d858953cd6f1d0b170df7669a89b502a72ca69a570349 \
  src/_protoc \
  6a589abf053394c14516e4c77a8571f47dbaf117c7e3af08674bffef2f5649c6 \
  src/_pygmentize \
  fcf1f1eba3e0d31dbb9446e0ce39b76704d9d3c8248d3158d00fcae761df256d \
  src/_qmk \
  28a4f34bb9d1072343c177413ec6f32892b75a91d87a4afcff37ad5174016154 \
  src/_rails \
  f84049237f4f66cce0a2871ff193de0513ba5bf162784cb99bcce363995ed0aa \
  src/_ralio \
  9ebf321dc0a9c7b3c31a514abb2cf358d66d8c9ff9a660ab5636e4d3c7374388 \
  src/_redis-cli \
  47675c617273cd03b5932c462df11f5112aafde25f29f02e09e3b03576847c5d \
  src/_rfkill \
  45aa2dcdde5a784d853a884c42edc8dcbd840dfb20adc44168d926238d6371dd \
  src/_rkt \
  ec206368081ab5d7e8adf84544d5231d57f7fc0fd7934effd386a37a89ed55e8 \
  src/_rmlint \
  8c82fc86917e82f6952ae0fc38c31850bd24e94376050aaed48a38484198e37c \
  src/_rslsync \
  27a1bbbf2eb47e491e901335d3a953886f5e61d852a00e24bf0ee6e8df4fe592 \
  src/_rspec \
  608458e075cf598fd4c5f0e53707c75f620de7d9f8df5e4afd62f2eb10846b64 \
  src/_rsvm \
  b8548a9bdc68fc3a3d731e4230dbf673f5557669cce5e1a364cc917d1edf9bbf \
  src/_rubocop \
  b5c82476128a2ba06d9946f0cddae243c2351cac5de31a7b3398b0c641252f3d \
  src/_sbt \
  9cc31bc16fedc86a8a33d57856035e1c6a616f1b3b9523596fb9fe7aa0a42ddb \
  src/_scala \
  ae6e8dd13492ae6c7ce44338ff3d7acc5644d72af7ee15c9aceffb68c16ee9ec \
  src/_scrub \
  4a3f8c2f81b1662da782c10cc145b37356d3b473e6c5f92e32e827602c712bd7 \
  src/_sdd \
  9cfcf9154f5b6613ff687b30a2ce21d62582ec00aa87817dc17d9a5167fa4cb5 \
  src/_setcap \
  95014bd37f1398a90cc59ace974484acf51020661968907752221edeb7e345a2 \
  src/_setup.py \
  54fa5bf6fb3f0c4f8898b264f7f4c06b6eca7559434d02b16ad8bf37816ccd5d \
  src/_sfdx \
  8f753daf8485c626309095679a94320ba78a9448874573b185e8c1cd7043ee80 \
  src/_shellcheck \
  3ff56d9ac0b67c108caa3a01758cb224373aba1c8d89fab20e22fdccfa87af8c \
  src/_showoff \
  ef4f78abfbb505d00b1fe953a53846de2ca3a34adb877b70656f6c9f83a53922 \
  src/_srm \
  20edb1f9c85424037cc35956f3af216c553abaf79b87176c9601f7ee314b6c79 \
  src/_stack \
  1c33f34e351fecf68b96fa0fa859c54dc30a5bb2a9ab79b4566b0cbebd953678 \
  src/_subl \
  716e4dc12fc5d76692fc389ddb3d7d0a81eb0f6292e8740fd03b49df049da5ee \
  src/_subliminal \
  bd128dff6d05c2a1f0e5456a9f8160cb18a2b9fba956512b812a09085b97849c \
  src/_supervisorctl \
  dacc4fdb76e235342152c17e056dc9996f8fe2b3d5b78c9bfc81578e66490c22 \
  src/_svm \
  87ff3de139f566e99460b2363e43e65d1f05e26174f4618c5354b297e59e2b44 \
  src/_tarsnap \
  4962e57919bf31ff198f16d07b1dad7c1b1051a44d25cc11bba7bccb90f75be4 \
  src/_teamocil \
  3b3a26cac5aaf2fa51a4dde2581791f9ed89fcb95e34da0af08b9c6714fc17c2 \
  src/_thor \
  eb81cd814feb464160bac17eb09830d5ffb378a5d27d0bf6a3fdcf70f3a70b2f \
  src/_tmuxinator \
  1828df6380cae93f3f29f163fb0e3e99a192c128c7f282d3911d74efa8a45433 \
  src/_tmuxp \
  6bb542b0709c5168af622d0711776f8ea493c2808f6e4442afa589e1c76e1abf \
  src/_tox \
  733f2d55ac96399cf7334babdf73fbb42cd93e92f2420569fcd8bdaf2fadbeb3 \
  src/_trash \
  72f18bde7df91b3575e929c72cd41b0feb2bae5f439a239bde80ef2fb2b71128 \
  src/_trash-empty \
  2fc1acea3c49fcdf0ae11083b9f5823499dd53c052213f9c06d02ced4d16de70 \
  src/_trash-list \
  3b877cd24112f8ef0c6cc7b9e4123e2b1cad16bd0da50ab3aeac0480d99ef7cb \
  src/_trash-put \
  72a3c562b76410eca403d2c515dcb99fca5f308337bc5934002d4982a62ae4c7 \
  src/_trash-restore \
  9cbe9c8b16362d571daa178a1678bfd185dafdb8c816cae3fd133aceafc0de31 \
  src/_udisksctl \
  2149a93a0a97d6f37bda16e94cefcdf16f5defe05abe5b12384878573390fc97 \
  src/_ufw \
  5cb9e6857a7d550b52721f609835d9fdf4dc750994b9294903ea01b525dc2034 \
  src/_vagrant \
  d957c718234d070456b82230f52d52839df7b3422cae3935fffbfb9f96ea7222 \
  src/_virtualbox \
  92c61e50643c27419484fc61945c04b71f2cdde5edccc479dcb82b233eb936e6 \
  src/_vnstat \
  b36bb58d83b34b8e7d58d38c4571db6196ba2a524a0550e1db2ddd0686b99844 \
  src/_wemux \
  1ab405faa5b1fdd27f21a3817d453d0411deafb2ad1d7b333fb2098cca44d1fc \
  src/_wg-quick \
  0279db31595c0a897b54a92582a0232132d03111e6db87374ea832bfe34910d0 \
  src/_xinput \
  1eea9d66f06b34e7dbbb71225197f5bf0cb555148dda05c222496a2b590af1f6 \
  src/_xsel \
  8602f840f4da03b923668fe6aeb1cad393035ef477f029cb7f24a0cd6c9cf327 \
  src/_yaourt \
  0f8b764e4f20592c2bdecfdb99b04c4597eee3b21092932e38340ec7df3e5da6 \
  src/_yarn \
  813e2741667c4689de72b82eb37277de65cd5bfcb79eb121141ee5a736d85150 \
  src/_zcash-cli \
  f1a5777862088993ff44524cf8f0c1142ed9ea213b4cf5f5bffe43bd060bb8ff \
  && {
    source ~/.zshrc-deps/zsh-completions/zsh-completions.plugin.zsh
  }
# ----------------------------------------------------------------------------------------------- #


# [ UNSET UNNEEDED FUNCTIONS ]------------------------------------------------------------------- #
unset -f __ZSHRC__bindkeys
unset -f __ZSHRC__deps_fetch
unset -f __ZSHRC__deps_check_sha256sum
# ----------------------------------------------------------------------------------------------- #


((1))                                               # All's well that ends well

# vim: set ts=2 sw=2 tw=100 et :
