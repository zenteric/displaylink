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
CLEAR="\033[0m"
CYAN="\033[0;36m"
LTCYAN="\033[1;36m"
GREEN="\033[0;32m"
LTGREEN="\033[1;32m"
BLUE="\033[0;34m"
LTBLUE="\033[1;34m"
PURPLE="\033[0;35m"
LTPURPLE="\033[1;35m"
RED="\033[0;31m"
LTRED="\033[1;31m"
BROWN="\033[0;33m"
YELLOW="\033[1;33m"

# Dependencies
deps=(unzip linux-headers-$(uname -r) dkms lsb-release)

dep_check() {
   echo -n "Checking dependencies..."
   for dep in ${deps[@]}
   do
      if ! dpkg -s $dep > /dev/null 2>&1
      then
   echo -e "[${GREEN}${dep} not found ${CLEAR}]"
	 read -p "Install? [y/N] " response
	 response=${response,,} # tolower
	 if [[ $response =~ ^(yes|y)$ ]]
	 then
	    if ! sudo apt-get install $dep
	    then
	       echo "$dep installation failed.  Aborting."
	       exit 1
	    fi
	 else
	    echo "Cannot continue without $dep.  Aborting."
	    exit 1
	 fi
      else
	 echo "$dep is installed"
      fi
   done
}

distro_check(){

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

# Unsupported platform message
message(){
echo -e "\n------------------------------------------------------\n"
echo -e "Unsuported platform: $platform"
echo -e ""
echo -e "This tool is Open Source and feel free to extend it"
echo -e "GitHub repo: https://goo.gl/6soXDE"
echo -e "\n------------------------------------------------------\n"
}

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
elif [ "$lsb" == "Debian" ];
then
	if [ $codename == "jessie" ] || [ $codename == "stretch" ] || [ $codename == "sid" ];
	then
		echo -e "\nPlatform requirements satisfied, proceeding ...\n"
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
echo -e "\nDownloading DisplayLink Ubuntu driver:"
dlurl="http://www.displaylink.com/downloads/file?id=607"
wget -O DisplayLink_Ubuntu_${VERSION}.zip $dlurl
# prep
mkdir $DRIVER_DIR
echo -e "\nPrepring for install ...\n"
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
echo -e "\nInstalling ... \n"
cd $DRIVER_DIR/displaylink-driver-${VERSION} && sudo ./displaylink-installer.sh install

echo -e "\nInstall complete, please reboot to apply the changes\n"
}

# uninstall
uninstall(){

echo -e "\nUninstalling ...\n"

sudo displaylink-installer uninstall
sudo rmmod evdi

# ToDo: make clean-up a seperate step
# add confirmation before removing
#cd -
#rm -r $DRIVER_DIR
#rm DisplayLink_Ubuntu_${VERSION}.zip

echo -e "\nUninstall complete\n"
}

post(){
eval $(rm -r $driver_dir)
eval $(rm DisplayLink_Ubuntu_${VERSION}.zip)
}

echo -e "\nDisplayLink driver for Debian GNU/Linux\n"

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
