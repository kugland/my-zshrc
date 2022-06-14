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
# Some wild heuristics to detect if we're running under PuTTY.
[[ $TERM = putty* ]]; __ZSHRC__putty=$(( ! $? ))

if (( ! __ZSHRC__putty && __ZSHRC__ssh_session )) && [[ $TERM = xterm* ]] {
  __ZSHRC__putty=1
  for challenge response (
    $'\eZ' $'\e[?6'                                 # DECID: terminal type query.
    $'\e[>c' $'\e[>0;136;0'                         # DA: report xterm version.
  ) {
    stty -echo
    print -n -- $challenge
    read -r -d c -s TERM_RESPONSE
    stty echo
    [[ $TERM_RESPONSE != $response ]] \
      && __ZSHRC__putty=0 \
      && break
  }
  unset TERM_RESPONSE
}
readonly __ZSHRC__putty
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

# Disable application mode when leaving ZLE ----------------------------------------------------- #
zle-line-finish() {
  ((${+terminfo[rmkx]})) && echoti rmkx             # Disable application mode
}

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

zle-line-init() {
  __ZSHRC__zlelineinit_overwrite
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

  RPROMPT="\${__ZSHRC__overwrite_prompt}%(1j.  $jobs_indicator.)%(0?..  $error_indicator)$gitstatus_prompt"

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
if [[ -r /usr/share/gitstatus/gitstatus.plugin.zsh ]] {
  source /usr/share/gitstatus/gitstatus.plugin.zsh

  # Sets GITSTATUS_PROMPT to reflect the state of the current git repository.
  function __ZSHRC__gitstatus_prompt_update() {
    gitstatus_prompt=''                             # Reset git status prompt.

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

  # On every prompt, fetch git status and set GITSTATUS_PROMPT.
  #add-zsh-hook precmd __ZSHRC__gitstatus_prompt_update
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


# [ CUSTOMIZE AND COLORIZE SOME COMMANDS ]------------------------------------------------------- #
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
# The paths here are the ones used by Arch Linux's packages 'zsh-history-substring-search' and
# 'zsh-syntax-highlighting'. In other systems, these paths may be different. If the files are not
# found, we'll fail silently.
for plugin (
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
  /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
) { 2>/dev/null source $plugin }

# If history-substring-search is available, bind Ctrl+PageUp and Ctrl+PageDown to it.
((${+functions[history-substring-search-up]})) \
  && __ZSHRC__bindkeys CtrlPageUp history-substring-search-up
((${+functions[history-substring-search-down]})) \
  && __ZSHRC__bindkeys CtrlPageDown history-substring-search-down
# ----------------------------------------------------------------------------------------------- #


((1))                                               # All's well that ends well
