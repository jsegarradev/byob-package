#!/bin/bash

######## PKG Vars ########
PKG_MANAGER="apt"
### FIXME: quoting UPDATE_PKG_CACHE and PKG_INSTALL hangs the script, shellcheck SC2086
UPDATE_PKG_CACHE="${PKG_MANAGER} update -qq"
UPGRADE_PKG_CACHE="${PKG_MANAGER} upgrade --yes"
PKG_INSTALL="${PKG_MANAGER} --yes install"
SUDO="sudo"

main() {
    rootCheck
    installBaseRepos
    installDocker
    addUserToDocker
    # Cleanup
    unset PKG_MANAGER
    unset UPDATE_PKG_CACHE
    unset PKG_INSTALL
    unset SUDO
    sleep 1
    exit
}
rootCheck() {
    if [[ $EUID -eq 0 ]];then
        say "You are root!"
        say
        say "Docker is not gonna be happy."
    else
        say "Verify your user."
        # Check if it is actually installed
        # If it isn't, exit because the install cannot complete
        if [[ $(dpkg-query -s sudo) ]];then
            export SUDO="sudo"
            export SUDOE="sudo -E"
            $SUDO echo "::: Verification Complete"
        else
            say "Please install sudo."
            exit 1
        fi
    fi
}

installBaseRepos() {
    say "Fetch fresh packages for PKG"
    if [[ $EUID -eq 0 ]];then
        ${UPDATE_PKG_CACHE} &> /dev/null
    else
        $SUDO ${UPDATE_PKG_CACHE} &> /dev/null
    fi
    say "Upgrading PKG"
    if [[ $EUID -eq 0 ]];then
        ${UPGRADE_PKG_CACHE} &> /dev/null
    else
        $SUDO ${UPGRADE_PKG_CACHE} &> /dev/null
    fi
    local REQU_REPOS=(
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
    )
    for i in ${REQU_REPOS[@]}; do
        if [[ $EUID -eq 0 ]];then
            say "Installing $i..."
            ${PKG_INSTALL} $i &> /dev/null
        else
            say "Installing $i..."
            $SUDO ${PKG_INSTALL} $i &> /dev/null
        fi
    done
}

installDocker() {
    say "Setting up Docker..."
    curl -fsSL https://get.docker.com | bash
}

addUserToDocker() {
    say "Configure Docker Container permissions"
    local USER_ME=$(whoami)
    if [[ $EUID -eq 0 ]];then
        usermod -aG docker $USER_ME  &> /dev/null
    else
        $SUDO usermod -aG docker $USER_ME  &> /dev/null
    fi
}
say() {
    echo "::: $@"
}
main
