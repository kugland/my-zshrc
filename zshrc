# MIT License

# Copyright (c) 2022 André Kugland

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software
# and associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# Set emulation mode to 'zsh'.
emulate -R zsh

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
path=()                                             # Clear the path.
for dir (                                           # Add some sane defaults to the PATH:
  /{usr/{local/,},}{s,}bin                          # s?bin directories under /usr/local, /usr & /
  /usr/{,local/}games                               # games directories under /usr & /usr/local
  /snap/bin                                         # snap binaries
) {
  [[ -h $dir ]] && continue                         # Skip symlinks.
  [[ -d $dir ]] || continue                         # Skip non-directories.
  [[ $(zstat +uid $dir) = 0 ]] || continue          # Skip non-root-owned directories.
  [[ $(zstat +gid $dir) = 0 ]] || continue          # Skip non-root-owned directories.
  local perm=$(zstat +mode $dir)                    # Skip directories that have set[ug]id set, or
  (((perm & 3647) == 45)) || continue               # sticky bits, or that are group or world-
                                                    # writable.
  path+=($dir)                                      # Add directory to the path.
}

# Dynamic linker -------------------------------------------------------------------------------- #
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib      # Set the default library path.
export LD_PRELOAD=''                                # Disable LD_PRELOAD.
export LD_AUDIT=''                                  # Disable LD_AUDIT.
export LD_DYNAMIC_WEAK=0                            # Do not allow weak symbols to be overridden.
export LD_POINTER_GUARD=1                           # Enable pointer guard.
readonly LD_{LIBRARY_PATH,PRELOAD,AUDIT,DYNAMIC_WEAK,POINTER_GUARD} # Make variables readonly.
# ----------------------------------------------------------------------------------------------- #


# [ LOAD SCRIPTS FROM /ETC/PROFILE.D ]----------------------------------------------------------- #
append_path() {                                     # Append a path to the PATH variable.
  emulate -L zsh                                    # This function will be available for scripts
  ((path[(Ie)$1])) && return || path+=($1)          # in /etc/profile.d.
}
for script (/etc/profile.d/*.sh) {
  [[ -x "$script" ]] && emulate bash -c "source $script"  # Source script using bash emulation.
}
unset -f append_path
# ----------------------------------------------------------------------------------------------- #


# [ EXIT IF NON-INTERACTIVE SHELL ]-------------------------------------------------------------- #
[[ $- = *i* ]] || return
# ----------------------------------------------------------------------------------------------- #


# ----------------------------------------------------------------------------------------------- #
#                                   START OF INTERACTIVE SECTION
# ----------------------------------------------------------------------------------------------- #

# [ LOAD FUNCTIONS AND MODULES FOR INTERACTIVE SHELLS ]------------------------------------------ #
zmodload zsh/complist zsh/terminfo zsh/zle
zmodload -m -F zsh/files b:zf_mkdir
autoload -Uz add-zle-hook-widget add-zsh-hook compinit is-at-least
# ----------------------------------------------------------------------------------------------- #


# [ SET SHELL OPTIONS ]-------------------------------------------------------------------------- #
IFS=$' \t\n\000'                                    # Set IFS to space, tab, newline and null.
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
[[ $COLORTERM = (24bit|truecolor) ]]; ((?)); __ZSHRC__color24bit=$?  # ((?)) means $? = $? ? 0 : 1
((__ZSHRC__color24bit)) || [[ $TERM = *256color ]]; ((?)); __ZSHRC__color8bit=$?

# If 24-bit color is not supported, and Zsh version is at least 5.7.0, we can use the module
# 'zsh/nearcolor' to approximate 24-bit colors as 8-bit colors. On 4-bit terminals, your mileage
# may vary; on $TERM = linux, for example, the resulting 256-color escapes will result in bright
# white text.
! ((__ZSHRC__color24bit)) && is-at-least 5.7.0 $ZSH_VERSION && zmodload zsh/nearcolor

# __ZSHRC__color prints its first argument if the terminal supports 256-color, otherwise it prints
# its second argument. It's needed because there's no nearcolor equivalent for 4-bit color
# terminals.
if ((__ZSHRC__color8bit)) {
  __ZSHRC__color() { print -n $2 }
} else {
  __ZSHRC__color() { print -n $1 }
}
# ----------------------------------------------------------------------------------------------- #


# [ DETECT SSH SESSIONS ]------------------------------------------------------------------------ #
# First we try the easy way: if SSH_CONNECTION is set, we're running under SSH.
__ZSHRC__ssh_session=${${SSH_CONNECTION:+1}:-0}

# However, if SSH_CONNECTION is not set, then it might be because we're running under sudo, and the
# environment variable wasn't passed by su(do)?. But we can still check whether we have sshd as an
# ancestor process. This will fail for normal users if /proc was mounted with hidepid=2. So this
# will fail if, while having hidepid=2, the user has su(do)'ed as root, and then again su(do)'ed
# as a normal user.
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
# ----------------------------------------------------------------------------------------------- #


# [ INACTIVITY TIMEOUT ]------------------------------------------------------------------------- #
# When not running on a virtual terminal, timeout after 10 minutes of inactivity.
if [[ $TTY != /dev/pts/* ]] { TMOUT=$((10 * 60)) }
# ----------------------------------------------------------------------------------------------- #


# [ LOAD LS COLORS ]----------------------------------------------------------------------------- #
# Load colors from ~/.dir_colors or /etc/DIR_COLORS, or use the default colors if they don't exist.
eval $(
  [[ -f ~/.dir_colors ]] && dircolors -b ~/.dir_colors && return
  [[ -f /etc/DIR_COLORS ]] && dircolors -b /etc/DIR_COLORS && return
  dircolors -b
)
# ----------------------------------------------------------------------------------------------- #


# [ SETUP KEYMAP ]------------------------------------------------------------------------------- #
# Make sure the terminal is in application mode when zle is active. Only then are the values from
# $terminfo valid.
__ZSHRC__zlelineinit_appmode() { ((${+terminfo[smkx]})) && echoti smkx }
__ZSHRC__zlelinefinish_appmode() { ((${+terminfo[rmkx]})) && echoti rmkx }
add-zle-hook-widget line-init __ZSHRC__zlelineinit_appmode
add-zle-hook-widget line-finish __ZSHRC__zlelinefinish_appmode

# Remove keymaps except .safe and main.
bindkey -D command emacs vicmd viins viopp visual

# Remove most key bindings in the main keymap.
bindkey -r '^'{'[','?',{,'[[','[O'}{A,B,C,D},E,F,G,H,I,J,K,L,N,O,P,Q,R,S,T,U,V,W,X,Y,Z}

# Only keys used in this script should be listed here.
typeset -A __ZSHRC__keys
__ZSHRC__keys=(
  [Tab]="${terminfo[ht]} ^I ^[[Z"
  [Backspace]="${terminfo[kbs]} ^H ^?"
  [Insert]="${terminfo[kich1]} ^[[2;5~"
  [Delete]="${terminfo[kdch1]} ^[[3;5~"
  [Home]="${terminfo[khome]} ^[OH ^[[H ^[[1~ ^[[1;5H"
  [End]="${terminfo[kend]} ^[OF ^[[F ^[[4~ ^[[1;5F"
  [PageUp]="${terminfo[kpp]} ^[[5;5~ ^[[5;3~"
  [PageDown]="${terminfo[knp]} ^[[6;5~ ^[[6;3~"
  [ArrowUp]="${terminfo[kcuu1]} ^[OA ^[[A ^[[1;5A"
  [ArrowDown]="${terminfo[kcud1]} ^[OB ^[[B ^[[1;5B"
  [ArrowRight]="${terminfo[kRIT]} ${terminfo[kcuf1]} ^[[1;2C ^[[1;3C ^[OC ^[[C ^[[1;5C"
  [ArrowLeft]="${terminfo[kLFT]} ${terminfo[kcub1]} ^[[1;2D ^[[1;3D ^[OD ^[[D ^[[1;5D"
  [CtrlBackspace]="^H"
  [CtrlDelete]="^[[3;5~"
  [CtrlPageUp]="^[[5;5~"
  [CtrlPageDown]="^[[6;5~"
  [CtrlRightArrow]="^[[1;5C"
  [CtrlLeftArrow]="^[[1;5D"
)

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

# Basic keyboard bindings.
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

# Clear screen (Ctrl+L)
__ZSHRC__clear_screen() {
  print -n '\e[3J'                                  # Clear the scrollback buffer.
  [[ $LANG = *.UTF-8 ]] && print -n '\e[%G'         # Select UTF-8 character set.
  zle clear-screen                                  # Call zle's clear-screen widget.
}
zle -N __ZSHRC__clear_screen
bindkey '^L' __ZSHRC__clear_screen

if [[ $TERM != linux ]] {
  # Move to next/previous word (Ctrl+RightArrow / Ctrl + LeftArrow)
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

# Insert and overwrite mode --------------------------------------------------------------------- #
__ZSHRC__overwrite_state=0                          # Overwrite mode state, 0 = off, 1 = on
__ZSHRC__overwrite_prompt=''                        # Overwrite mode indicator for RPROMPT

# Sets cursor shape according to insert/overwrite state and update the indicator.
__ZSHRC__cursorshape_overwrite() {
  if [[ $TTY = /dev/pts/* && -n $DISPLAY ]] {
    # Set the cursor shape (| for insert, _ for overwrite).
    print -n '\e]50;CursorShape='$((__ZSHRC__overwrite_state + 1))'\007'
  }
}

# Update the overwrite mode indicator.
__ZSHRC__indicator_overwrite() {
  ((__ZSHRC__overwrite_state)) \
    && __ZSHRC__overwrite_prompt=$__ZSHRC__overwrite_indicator \
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
  # Since zle's overwrite mode is not persistent, we need to restore the state on each line.
  ((__ZSHRC__overwrite_state)) && zle overwrite-mode
  __ZSHRC__cursorshape_overwrite
}

# Always set to insert cursor before running commands.
__ZSHRC__preexec_overwrite() {
  [[ $TTY = /dev/pts/* && -n $DISPLAY ]] && print -n '\e]50;CursorShape=1\007'
}
add-zle-hook-widget line-init __ZSHRC__zlelineinit_overwrite
add-zsh-hook preexec __ZSHRC__preexec_overwrite
# ----------------------------------------------------------------------------------------------- #


# [ PROMPT SETUP ]------------------------------------------------------------------------------- #
# A simple, but effective prompt
# Reset the terminal to an usable state.
PS1=''
PS1+=$'%{\e[0m%}'                                   # Reset color.
PS1+=$'%{\e(B\e)0%}'                                # Reset G0 and G1 charsets.
[[ $LANG = *.UTF-8 ]] && PS1+=$'%{\e%%G%}'          # Select UTF-8 character set
PS1+=$'%{\017%}'                                    # Disable VT100 pseudo-graphics.
PS1+=$'%{\e[3l%}'                                   # Don't show control characters.
PS1+=$'%{\e[4l%}'                                   # Disable insert mode.
PS1+=$'%{\e[20l%}'                                  # Do not add CR after LF, VT and FF.
PS1+=$'%{\e[?1l%}'                                  # Correct codes for cursor keys.
PS1+=$'%{\e[?5l%}'                                  # Disable reverse video.
PS1+=$'%{\e7\e[?6l\e8%}'                            # Fix cursor addressing.
PS1+=$'%{\e[?7h%}'                                  # Enable auto wrap.
PS1+=$'%{\e[?8h%}'                                  # Enable keyboard auto-repeat.
PS1+=$'%{\e[?25h%}'                                 # Enable cursor.
PS1+=$'%{\e[?1000l%}'                               # Disable X11 mouse events.
PS1+=$'%{\e[?1004l%}'                               # Disable focus events.
PS1+=$'%{\e[?2004h%}'                               # Enable bracketed paste.
PS1+=$'%{\e7\e[0;0r\e8%}'                           # Reset scrolling region.

# The main prompt.
((__ZSHRC__ssh_session)) && PS1+='%B%F{black}[%f%bssh%B%F{black}]%f%b ' # Show we're under ssh.
PS1+='${__ZSHRC__PS1_before_user_host}%(!..%n@)%m'  # user@hostname / hostname
PS1+='${__ZSHRC__PS1_before_path}%~'                # :path
PS1+='${__ZSHRC__PS1_after_path}'                   # % / #

# RPROMPT will contain:
RPROMPT='%b%k%f'
# the overwrite indicator, if overwrite is on;
RPROMPT+='${__ZSHRC__overwrite_prompt}'
# The number of jobs in the background, if there are any;
RPROMPT+='%(1j.  ${__ZSHRC__jobs_prompt_prefix}%j job%(2j.s.)${__ZSHRC__jobs_prompt_suffix}.)'
# The error code returned by the last command, if it was non-zero;
RPROMPT+='%(0?..  ${__ZSHRC__error_prefix}$?${__ZSHRC__error_suffix})'
# And, finally, the information from git status.
RPROMPT+='${__ZSHRC__git_prompt}'

# PS2 will be '» ' for depth 1, '» » ' for depth 2, etc.
# '»' is in ISO-8859-1, in CP437, in CP850, so it's probably safe to use it.
PS2='%B%F{black}%(1_.» .)%(2_.» .)%(3_.» .)%(4_.» .)%(5_.» .)%(6_.» .)%(7_.» .)%(8_.» .)%f%b'
# RPS2 will be type of the current open block (if, while, for, etc.)
# Make RPS2 show [cont] when we're in a continuation line (the previous line ended with '\').
RPS2='%B%F{black}[%f%b${${${:-$(print -P "%^")}//(#s)cmdsubst #/}//(#s)(#e)/cont}%B%F{black}]%f%b'


# Window title ---------------------------------------------------------------------------------- #
__ZSHRC__ellipsized_path_window_title() {
  local cwd=$(print -Pn '%~')                       # Current working directory.
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
      local head=${$(print -Pnr '%20>>$cwd%>>')%/*} # Get the head of the path.
      local tail=${$(print -Pnr '%20<<$cwd%<<')#*/} # Get the tail of the path.
      cwd=${head}/…/${tail}                         # Join and add ellipsis.
    }
    if [[ ${cwd[1]} != '~' ]] { cwd=/${cwd} }       # Prefix with '/' if it doesn't start with '~'.
  }
  print -n $cwd                                     # Print the path.
}

__ZSHRC__print_window_title() {
  local cwd=$(__ZSHRC__ellipsized_path_window_title) # Get the current directory (ellipsized).
  local cmd=$1                                      # Get the command name.
  print -n '\e]0;'                                  # Start the title escape sequence.
  ((__ZSHRC__ssh_session)) && print -Pnr '🌎 [%m] ' # If under SSH, add hostname and world emoji.
  ((UID)) || print -n '🔴 '                         # Add a red circle emoji if the user is root.
  print -nr $cwd                                    # Print the path.
  print -n ' • '                                    # Add a separator.
  print -nr ${cmd}                                  # Print the command name.
  print -n '\007'                                   # End the title escape sequence.
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
[[ -r /usr/share/gitstatus/gitstatus.plugin.zsh ]] && {
  source /usr/share/gitstatus/gitstatus.plugin.zsh

  # Sets GITSTATUS_PROMPT to reflect the state of the current git repository.
  function __ZSHRC__gitstatus_prompt_update() {
    __ZSHRC__git_prompt=''                          # Reset git status prompt.

    # Call gitstatus_query synchronously. Note that gitstatus_query can also be
    # called asynchronously; see documentation in gitstatus.plugin.zsh.
    gitstatus_query 'MY'                  || return 1  # error
    [[ $VCS_STATUS_RESULT == 'ok-sync' ]] || return 0  # not a git repo

    # Colors for git status, either 4-bit or 8-bit colors.
    local git_color=$(__ZSHRC__color '%B%F{red}' '%B%F{208}')
    local cyan=$(__ZSHRC__color '%F{cyan}' '%F{36}')
    local b_cyan=$(__ZSHRC__color '%B%F{cyan}' '%B%F{86}')
    local red=$(__ZSHRC__color '%F{red}' '%F{210}')
    local b_red=$(__ZSHRC__color '%B%F{red}' '%B%F{210}')
    local green=$(__ZSHRC__color '%F{green}' '%F{154}')
    local b_green=$(__ZSHRC__color '%B%F{green}' '%B%F{154}')

    local p="  ${git_color}git%f%b "                # Git status prefix
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

    # *42 (bright black) if has stashes.
    ((VCS_STATUS_STASHES)) && p+=" %B%F{black}*$VCS_STATUS_STASHES%b%f"
    # +42 (green) if has staged changes.
    ((VCS_STATUS_NUM_STAGED)) && p+=" $green+$b_green$VCS_STATUS_NUM_STAGED%b%f"
    # +42 (red) if has unstaged changes.
    ((VCS_STATUS_NUM_UNSTAGED)) && p+=" $red+$b_red$VCS_STATUS_NUM_UNSTAGED%b%f"
    # *42 (red) if has untracked files.
    ((VCS_STATUS_NUM_UNTRACKED)) && p+=" $red*$b_red$VCS_STATUS_NUM_UNTRACKED%b%f"
    # ↓42 (cyan) if behind the remote.
    ((VCS_STATUS_COMMITS_BEHIND)) && p+=" $cyan↓$b_cyan$VCS_STATUS_COMMITS_BEHIND%b%f"
    # ↑42 (cyan) if ahead of the remote.
    ((VCS_STATUS_COMMITS_AHEAD )) && p+=" $cyan↑$b_cyan$VCS_STATUS_COMMITS_AHEAD%b%f"
    # ←42 (cyan) if behind the push remote.
    ((VCS_STATUS_PUSH_COMMITS_BEHIND)) && p+=" $cyan←$b_cyan$VCS_STATUS_PUSH_COMMITS_BEHIND%b%f"
    # →42 (cyan) if ahead of the push remote.
    ((VCS_STATUS_PUSH_COMMITS_AHEAD)) && p+=" $cyan→$b_cyan$VCS_STATUS_PUSH_COMMITS_AHEAD%b%f"
    # 'merge' if the repo is in an unusual state.
    [[ -n $VCS_STATUS_ACTION ]] && p+=" $b_red$VCS_STATUS_ACTION%b%f"
    # !42 if has merge conflicts.
    ((VCS_STATUS_NUM_CONFLICTED)) && p+=" $red!$b_red$VCS_STATUS_NUM_CONFLICTED%b%f"

    __ZSHRC__git_prompt="${p}"
  }

  # Start gitstatusd instance with name "MY". The same name is passed to gitstatus_query in
  # __ZSHRC__gitstatus_prompt_update. The flags with -1 as values enable staged, unstaged,
  # conflicted and untracked counters.
  gitstatus_stop 'MY' && gitstatus_start -s -1 -u -1 -c -1 -d -1 'MY'

  # On every prompt, fetch git status and set GITSTATUS_PROMPT.
  add-zsh-hook precmd __ZSHRC__gitstatus_prompt_update
}

# Simple prompt and fancy prompt ---------------------------------------------------------------- #
# A simple prompt that will work nicely in a console with limited charset and only 16 colors,
# such as the Linux console.
__ZSHRC__simple_prompt() {
  __ZSHRC__PS1_before_user_host='%B%F{%(!.red.green)}'
  __ZSHRC__PS1_before_path='%f%b:%B%F{blue}'
  __ZSHRC__PS1_after_path='%f%b%# '
  __ZSHRC__overwrite_indicator="  %K{blue}%B%F{white} over %f%b%k"
  __ZSHRC__jobs_prompt_prefix='%K{magenta}%B%F{white} '
  __ZSHRC__jobs_prompt_suffix=' %f%b%k'
  __ZSHRC__error_prefix='%K{red}%B%F{white} '
  __ZSHRC__error_suffix=' %f%b%k'
  __ZSHRC__indicator_overwrite                      # # Update the overwrite indicator if needed.
}

# Completely unnecessary, but I like it.
# This prompt requires Nerd Fonts (https://www.nerdfonts.com/).
__ZSHRC__fancy_prompt() {
  # For the main prompt.
  local ps1usrcolor='%(!.#b24742.#47a730)'
  __ZSHRC__PS1_before_user_host="%K{$ps1usrcolor}%B%F{white} "
  __ZSHRC__PS1_before_path="%b%F{$ps1usrcolor}%K{#547bb5}"$'\uE0B4'" %B%F{white}"
  __ZSHRC__PS1_after_path="%b%F{#547bb5}%K{$ps1usrcolor}"$'\uE0B4'"%k%F{$ps1usrcolor}"$'\uE0B4'"%f "
  __ZSHRC__overwrite_indicator=$'%F{blue}\uE0B6%K{blue}%B%F{white}over%k%b%F{blue}\uE0B4%f'
  __ZSHRC__jobs_prompt_prefix=$'%F{magenta}\uE0B6%K{magenta}%B%F{white}'
  __ZSHRC__jobs_prompt_suffix=$'%k%b%F{magenta}\uE0B4%f'
  __ZSHRC__error_prefix=$'%F{red}\uE0B6%K{red}%B%F{white}'
  __ZSHRC__error_suffix=$'%k%b%F{red}\uE0B4%f'
  __ZSHRC__indicator_overwrite                      # # Update the overwrite indicator if needed.
}

# Select the prompt.
# The fancy prompt will be used if the terminal is a virtual TTY, X11 is available, we're using
# a UTF-8 locale, and we're not in a SSH session, the terminal supports 8-bit colors, otherwise
# the simple prompt will be used.
[[ $TTY = /dev/pts/* ]] \
  && [[ -n $DISPLAY ]] \
  && [[ $LANG = *.UTF-8 ]] \
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
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
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
__ZSHRC__ssh_hosts=()
if [[ -r ~/.ssh/config ]] {
  __ZSHRC__ssh_hosts=(${${${(@M)${(f)"$(<~/.ssh/config)"}:#Host *}#Host }:#*[*?]*}) 2>/dev/null
  __ZSHRC__ssh_hosts=(${(s/ /)${__ZSHRC__ssh_hosts}})
  if ((${#__ZSHRC__ssh_hosts})) {
    zstyle ':completion:*:scp:*' hosts $__ZSHRC__ssh_hosts
    zstyle ':completion:*:sftp:*' hosts $__ZSHRC__ssh_hosts
    zstyle ':completion:*:ssh:*' hosts $__ZSHRC__ssh_hosts
    zstyle ':completion:*:sshfs:*' hosts $__ZSHRC__ssh_hosts
  }
}
unset __ZSHRC__ssh_hosts
zstyle ':completion:*:scp:*' users
zstyle ':completion:*:sftp:*' users
zstyle ':completion:*:ssh:*' users
zstyle ':completion:*:sshfs:*' users
# Workaround for sshfs
[[ -n ${commands[sshfs]} ]] && function() _user_at_host() { _ssh_hosts "$@" }
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

for grep ({,e,f}grep bzgrep {,l,x}z{,e,f}grep) {    # Add colors to grep and friends.
  [[ -n ${commands[$grep]} ]] && alias "$grep=command $grep --color=auto"
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


# Some cleanup ---------------------------------------------------------------------------------- #
unset __ZSHRC__keys
unset -f __ZSHRC__bindkeys
# ----------------------------------------------------------------------------------------------- #
