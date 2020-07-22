# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/home/yourusername/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="bullet-train"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    ssh-agent
    vscode
    tmux
    systemd
    zsh-completions
    #  dotenv
)

# SSH Agent Config
zstyle :omz:plugins:ssh-agent identities id_rsa

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Custom
BULLETTRAIN_PROMPT_ORDER=(
    git
    dir
    status
)

#BULLETTRAIN_CONTEXT_BG=darkblue
#BULLETTRAIN_CONTEXT_FG=white
BULLETTRAIN_DIR_CONTEXT_SHOW=true
BULLETTRAIN_DIR_EXTENDED=0
BULLETTRAIN_DIR_BG=blue
BULLETTRAIN_DIR_FG=white

# Aliases
alias powershell="powershell.exe"
alias devStart="sudo service php7.2-fpm start && sudo service apache2 start && sudo service mysql start && sudo service mongodb start && sudo service redis-server start"
alias devStop="sudo service php7.2-fpm stop && sudo service apache2 stop && sudo service mysql stop && sudo service mongodb stop && sudo service redis-server stop"

# Ruby exports
export GEM_HOME=$HOME/gems
export PATH=$HOME/gems/bin:$PATH

# Auto Suggestions
source ~/.oh-my-zsh/custom/zsh-autosuggestions/zsh-autosuggestions.zsh
export SCREENDIR=~/.screen

# Bashcominit
autoload bashcompinit
bashcompinit
source /etc/bash_completion.d/wp-cli

# Fix Dircolors
eval `dircolors ~/.oh-my-zsh/custom/dircolors.256dark`

# Completions
autoload -U compinit && compinit
source /home/yourusername/.zsh/completion/gh

# Serveo
# export SERVEO_HOST=serveo
# alias serveo=/home/yourusername/Projects/personal/serveo-selfhost/serveo.sh

# Start
alias start='explorer.exe'

# Share
alias share=/home/yourusername/go/bin/share-cli

# Public Key
alias sshPublicKey='cat ~/.ssh/id_rsa.pub | clip.exe'

# Go
export GOPATH=$HOME/go
