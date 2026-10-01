export ANDROID_HOME="/home/Krish/Android/Sdk"
export ANDROID_SDK_ROOT="/home/Krish/Android/Sdk"
export PATH="/home/Krish/development/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:/home/Krish/android-studio/bin:/home/Krish/.local/bin:$PATH"
export QML_IMPORT_PATH="/home/Krish/.config/quickshell:/home/Krish/.config/quickshell/plugins:${QML_IMPORT_PATH:-}"
export QML2_IMPORT_PATH="/home/Krish/.config/quickshell:/home/Krish/.config/quickshell/plugins:${QML2_IMPORT_PATH:-}"
#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export TERMINAL=ghostty
export BROWSER=helium
export EDITOR=nvim
export VISUAL=nvim
export DEFAULT_AGENT=antigravity-cli
export SUDO_ASKPASS="/home/Krish/.local/bin/mechanic-askpass"

alias a='agent'

alias ls=lsd
alias agy='agy --dangerously-skip-permissions'
