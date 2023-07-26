#!/bin/bash

######## PKG Vars ########
PKG_MANAGER="apt"
### FIXME: quoting UPDATE_PKG_CACHE and PKG_INSTALL hangs the script, shellcheck SC2086
UPDATE_PKG_CACHE="${PKG_MANAGER} update -qq"
UPGRADE_PKG_CACHE="${PKG_MANAGER} upgrade --yes"
PKG_INSTALL="${PKG_MANAGER} --yes install"
SUDO="sudo"

STEP2URL="https://gitlab.com/vrl/vrl-package/-/tree/master/service/step2.desktop"

main() {
    installBaseRepos
    installDependensieRepos
    installDocker
    addUserToDocker
    makeStep2
    # Cleanup
    unset PKG_MANAGER
    unset UPDATE_PKG_CACHE
    unset PKG_INSTALL
    unset SUDO
    sleep 5
    say "Loggin out to apply changes..."
    say "Just logg back in again..."
    exit
}
installBaseRepos() {
    say "Fetch fresh packages for PKG"
    $SUDO ${UPDATE_PKG_CACHE} &> /dev/null
    say "Upgrading PKG"
    $SUDO ${UPGRADE_PKG_CACHE} &> /dev/null
    local REQU_REPOS=(
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
    )
    for i in ${REQU_REPOS[@]}; do
        say "Installing $i..."
        $SUDO ${PKG_INSTALL} $i &> /dev/null
    done
}
installDependensieRepos() {
    $SUDO ${UPDATE_PKG_CACHE} &> /dev/null
    local REQU_REPOS=(
    avahi-daemon
    gcc
    cmake
    neofetch
    htop
    upx-ucl
    build-essential
    zlib1g-dev
    python3
    python3-pip
    python3-opencv
    python3-wheel
    python3-setuptools
    python3-dev
    python3-distutils
    python3-venv
    )
    for i in ${REQU_REPOS[@]}; do
        say "Installing $i..."
        $SUDO ${PKG_INSTALL} $i &> /dev/null
    done
}
installDocker() {
    if [[ "$(which docker)" == "/usr/bin/docker" ]]; 
    then 
        say "Docker is already installed..."
    else 
        say "Setting up Docker..."
        curl -fsSL https://get.docker.com | bash
    fi
}
addUserToDocker() {
    say "Configure Docker Container permissions"
    local USER_ME=$(whoami)
    $SUDO usermod -aG docker $USER_ME  &> /dev/null
}
makeStep2(){
    cp $HOME/.bashrc $HOME/.bashrc.old
    echo "curl -L https://gitlab.com/vrl/vrl-package/-/raw/master/auto_install/step2.sh | bash" >> $HOME/.bashrc
}
say() {
    echo "::: $@"
}
main
