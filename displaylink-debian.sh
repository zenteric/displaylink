#!/bin/bash
#
# DisplayLink driver installer for Linux

# Usage:
#
# Set Current release DRIVER_DIR here and run script

# Exit on error. Append || true if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

# Global Variables
VERSION=1.1.62
DRIVER_DIR=$VERSION

# Set magic variables for current file, directory, os, etc.
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__os="Linux"
# Color palette
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
CLEAR=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)
# Dependencies
deps=(unzip linux-headers-$(uname -r) dkms lsb-release)

dep_check() {
   echo -e "Checking dependencies..."
   for dep in ${deps[@]}
   do
      if ! dpkg -s $dep > /dev/null 2>&1
      then
   echo -e "[${RED}${dep}${CLEAR} not found]"
	 read -p "Install? [y/N] " response
	 response=${response,,} # tolower
	 if [[ $response =~ ^(yes|y)$ ]]
	 then
	    if ! sudo apt-get install $dep
	    then
         echo -ne "$dep                             "
	       echo -e "[${RED}failed.${CLEAR}]  Aborting."
	       exit 1
	    fi
	 else
	    echo -e "${RED}Cannot continue without $dep.${CLEAR}  Aborting."
	    exit 1
	 fi
      else
        printf "%-40s  %-30s\n" "$dep" "[${GREEN}installed${CLEAR}]"
      fi
   done
}

distro_check(){

echo -e "Checking platform requirements: "

# RedHat
if [ -f /etc/redhat-release ];
then
	echo "This is a Redhat based distro ..."
	# ToDo:
	# Add platform type message for RedHat
	exit 1
else

# Confirm dependencies are in place
dep_check

# Checker parameters
lsb="$(lsb_release -is)"
codename="$(lsb_release -cs)"
platform="$(lsb_release -ics | sed '$!s/$/ /' | tr -d '\n')"

# Ubuntu
if [ "$lsb" == "Ubuntu" ];
then
	if [ $codename == "trusty" ] || [ $codename == "vivid" ] || [ $codename == "wily" ] || [ $codename == "xenial" ];
	then
		echo -e "\nPlatform requirements satisfied, proceeding ...\n"
	else
		message
		exit 1
	fi
# Elementary
elif [ "$lsb" == "elementary OS" ];
then
    if [ $codename == "freya" ];
    then
		echo -e "\nPlatform requirements satisfied, proceeding ...\n"
    else
        message
        exit 1
    fi
# Debian
elif [ "${lsb}" == "Debian" ];
then
	if [ $codename == "jessie" ] || [ $codename == "stretch" ] || [ $codename == "sid" ];
	then
    echo -e "[${GREEN}OK${CLEAR}]"
		echo -e "\nPlatform ${lsb} requirements satisfied, proceeding ...\n"
	else
        message
        exit 1
	fi
else
	message
	exit 1
fi
fi
}

# Unsupported platform message
message(){
echo -e "\n======================================================\n"
echo -e "Unsuported platform: ${platform}"
echo -e ""
echo -e "This tool is Open Source and feel free to extend it"
echo -e "GitHub repo: https://github.com/zenteric/displaylink"
echo -e "\n======================================================\n"
}

sysinitdaemon_get(){

sysinitdaemon="systemd"

if [ "$lsb" == "Ubuntu" ];
then
	if [ $codename == "trusty" ];
	then
        sysinitdaemon="upstart"
	fi
# Elementary
elif [ "$lsb" == "elementary OS" ];
then
    if [ $codename == "freya" ];
    then
        sysinitdaemon="upstart"
    fi
fi

echo $sysinitdaemon
}

install(){
echo "========================================================================"
printf "%-10s  %-30s\n" " " "${GREEN}Downloading DisplayLink Ubuntu driver${CLEAR}"
echo "========================================================================"
dlurl="http://www.displaylink.com/downloads/file?id=607"
wget -O DisplayLink_Ubuntu_${VERSION}.zip $dlurl
# prep
mkdir $DRIVER_DIR
echo "========================================================================"
printf "%-10s  %-30s\n" " " "${GREEN}Prepring for install${CLEAR}"
echo "========================================================================"
test -d $DRIVER_DIR && /bin/rm -Rf $DRIVER_DIR
unzip -d $DRIVER_DIR DisplayLink_Ubuntu_${VERSION}.zip
chmod +x $DRIVER_DIR/displaylink-driver-${VERSION}.run
./$DRIVER_DIR/displaylink-driver-${VERSION}.run --keep --noexec
mv displaylink-driver-${VERSION}/ $DRIVER_DIR/displaylink-driver-${VERSION}

# get sysinitdaemon
sysinitdaemon=$(sysinitdaemon_get)

# modify displaylink-installer.sh
sed -i "s/SYSTEMINITDAEMON=unknown/SYSTEMINITDAEMON=$sysinitdaemon/g" $DRIVER_DIR/displaylink-driver-${VERSION}/displaylink-installer.sh
sed -i "s/"179"/"17e9"/g" $DRIVER_DIR/displaylink-driver-${VERSION}/displaylink-installer.sh
sed -i "s/detect_distro/#detect_distro/g" $DRIVER_DIR/displaylink-driver-${VERSION}/displaylink-installer.sh
sed -i "s/#detect_distro()/detect_distro()/g" $DRIVER_DIR/displaylink-driver-${VERSION}/displaylink-installer.sh
sed -i "s/check_requirements/#check_requirements/g" $DRIVER_DIR/displaylink-driver-${VERSION}/displaylink-installer.sh
sed -i "s/#check_requirements()/check_requirements()/g" $DRIVER_DIR/displaylink-driver-${VERSION}/displaylink-installer.sh

# install
echo "========================================================================"
printf "%-10s  %-30s\n" " " "${GREEN}Installing${CLEAR}"
echo "========================================================================"
cd $DRIVER_DIR/displaylink-driver-${VERSION} && sudo ./displaylink-installer.sh install

echo "========================================================================"
printf "%-10s  %-30s\n" " " "${GREEN}Completed Install${CLEAR}"
echo "========================================================================"
}

# uninstall
uninstall(){
echo "========================================================================"
printf "%-10s  %-30s\n" " " "${GREEN}Uninstalling${CLEAR}"
echo "========================================================================"

sudo displaylink-installer uninstall
sudo rmmod evdi

# ToDo: make clean-up a seperate step
# add confirmation before removing
#cd -
#rm -r $DRIVER_DIR
#rm DisplayLink_Ubuntu_${VERSION}.zip
echo "========================================================================"
printf "%-10s  %-30s\n" " " "${GREEN}Uninstall Complete${CLEAR}"
echo "========================================================================"
}

post(){
eval $(rm -r $driver_dir)
eval $(rm DisplayLink_Ubuntu_${VERSION}.zip)
}

echo "========================================================================"
printf "%-10s  %-30s\n" " " "${GREEN}DISPLAYLINK Install Tool${CLEAR}"
printf "%-10s  %-30s\n" " " "${GREEN}DISPLAYLINK VERSION: ${BLUE}${VERSION}${CLEAR}"

printf "%-10s  %-30s\n" " " "${GREEN}DisplayLink driver for Debian GNU/Linux${CLEAR}"
echo "========================================================================"

read -p "[$(echo -e ${GREEN} I ${CLEAR}] Install)
[$(echo -e ${RED} U ${CLEAR}] Uninstall)

Select an option: [i/u]: " answer

if [[ $answer == [Ii] ]];
then
	distro_check
	install
elif [[ $answer == [Uu] ]];
then
	distro_check
	uninstall
else
	echo -e "\nWrong key, aborting ...\n"
	exit 1
fi
