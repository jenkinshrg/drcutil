#!/usr/bin/env bash

source config.sh
FILENAME="$(echo $(cd $(dirname "$BASH_SOURCE") && pwd -P)/$(basename "$BASH_SOURCE"))"
RUNNINGSCRIPT="$0"
trap 'err_report $LINENO $FILENAME $RUNNINGSCRIPT; exit 1' ERR

setupenv_OpenRTM-aist() {
    if [ $OSNAME = "Darwin" ]; then
	brew install autoconf automake libtool omniorb
    else
	sudo apt-get -y install autoconf
        sudo apt-get -y install libtool-bin
    fi
}

setupenv_openhrp3() {
    if [ $OSNAME = "Darwin" ]; then
	brew install cmake eigen boost pkg-config jpeg libpng
    else
	cd $SRC_DIR/openhrp3/util
	./installPackages.sh packages.list.$DIST_KIND.$DIST_VER
	sudo apt-get -y remove openrtm-aist-dev openrtm-aist || true # install from source

	sudo sed -i -e 's/giopMaxMsgSize = 2097152/giopMaxMsgSize = 2147483648/g' /etc/omniORB.cfg

	if [ "$BUILD_GOOGLE_TEST" = "ON" ]; then
            sudo apt-get -y install libgtest-dev
	fi
    fi
}

setupenv_pcl() {
    if [ $OSNAME = "Darwin" ]; then
	brew install pcl
    else
	if [ "$DIST_VER" = "14.04" ]; then
	    sudo add-apt-repository -y ppa:v-launchpad-jochen-sprickerhof-de/pcl
	    sudo apt-get update || true #ignore checksum error
	    sudo apt-get -y install libpcl-all
	else
	    sudo apt-get -y --allow-unauthenticated install libpcl-dev libproj-dev
	fi
    fi
}

setupenv_octomap() {
    if [ $OSNAME = "Darwin" ]; then
	brew install octomap
    else
        if ([ "$DIST_KIND" == "ubuntu" ] && [ "$DIST_VER" != "14.04" ]) || ([ "$DIST_KIND" == "debian" ] && [ "$DIST_VER" == "10" ]); then
	    sudo apt-get -y install liboctomap-dev
	fi
    fi
}

setupenv_hrpsys-base() {
    if [ $OSNAME = "Darwin" ]; then
	brew install opencv sdl boost-python
    else
	sudo apt-get -y --force-yes install libxml2-dev libsdl-dev libglew-dev libopencv-dev libqhull-dev freeglut3-dev libxmu-dev python-dev libboost-python-dev ipython
        sudo apt-get -y --force-yes install openrtm-aist-python || true
	if [ "$DIST_KIND" = "ubuntu" ] && [ "$DIST_VER" != "18.04" ] && [ "$DIST_VER" != "20.04" ]; then
            sudo apt-get -y --force-yes install libcvaux-dev libhighgui-dev
	fi
    fi
}

setupenv_HRP2() {
    :
}

setupenv_HRP2KAI() {
    :
}

setupenv_HRP5P() {
    :
}

setupenv_HRP4CR() {
    :
}

setupenv_sch-core() {
    :
}
    
setupenv_state-observation() {
    if [ $OSNAME = "Darwin" ]; then
	brew install doxygen
    else
	sudo apt-get -y install libboost-test-dev libboost-timer-dev
    fi
}

setupenv_hmc2() {
    if [ $OSNAME = "Darwin" ]; then
	brew install libyaml
    else
	sudo apt-get -y install libyaml-dev libncurses5-dev libglpk-dev
    fi
}

setupenv_hrpsys-private() {
    :
}

setupenv_hrpsys-humanoid() {
    if [ $OSNAME != "Darwin" ]; then
	sudo apt-get -y install libusb-dev
    fi
}

setupenv_hrpsys-state-observation() {
    :
}

setupenv_trap-fpe() {
    :
}

setupenv_savedbg() {
    if [ "$DIST_VER" = 14.04 ]; then
        REALPATH=realpath
    else
        REALPATH=
    fi
    sudo apt-get -y install elfutils $REALPATH
}

setupenv_choreonoid() {
    if [ $OSNAME = "Darwin" ]; then
	brew install gettext qt zbar
    else
	#choreonoid
	cd $SRC_DIR/choreonoid/misc/script
	./install-requisites-$DIST_KIND-$DIST_VER.sh

	#hrpcnoid
	sudo apt-get -y --allow-unauthenticated install libzbar-dev python-matplotlib
    fi
}

setupenv_is-jaxa() {
    :
}

setupenv_takenaka() {
    :
}

setupenv_flexiport() {
    :
}

setupenv_hokuyoaist() {
    :
}

setupenv_rtchokuyoaist() {
    :
}


if [ ! $# -eq 0 ]; then
    PACKAGES=$@
fi

for package in $PACKAGES; do
    setupenv_$package
done

