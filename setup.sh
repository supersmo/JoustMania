#!/bin/bash

setup() {
    # Prevent apt from prompting us about restarting services.
    export DEBIAN_FRONTEND=noninteractive
    HOMENAME=`logname`
    HOMEDIR=/home/$HOMENAME
    cd $HOMEDIR
    sudo apt-get install -y espeak

    espeak "starting software upgrade"
    sudo apt-get update -y || exit -1
    sudo apt-get upgrade -y || exit -1

    espeak "Installing required software dependencies"
    #TODO: remove pyaudio and dependencies
    #install components
    sudo apt-get install -y  \
        python3 python3-dev python3-pip \
        python3-pkg-resources python3-setuptools libdpkg-perl \
        libsdl1.2-dev libsdl-mixer1.2-dev libsdl-sound1.2-dev \
        libportmidi-dev portaudio19-dev \
        libsdl-image1.2-dev libsdl-ttf2.0-dev \
        libblas-dev liblapack-dev \
        bluez bluez-tools iptables rfkill supervisor cmake ffmpeg \
        libudev-dev swig libbluetooth-dev \
        alsa-utils alsa-tools libasound2-dev libsdl2-mixer-2.0-0 \
        python-dbus-dev python3-dbus libdbus-glib-1-dev usbutils espeak libatlas-base-dev || exit -1

    espeak "Installing PS move A.P.I. software updates"
    #install components for psmoveapi
    sudo apt-get install -y \
        build-essential \
        libv4l-dev libopencv-dev \
        libudev-dev libbluetooth-dev \
        libusb-dev || exit -1

    espeak "Installing software libraries"
    VENV=$HOMEDIR/JoustMania/venv
    # We install nearly all python deps in the virtualenv to avoid concflicts with system, except
    # numpy and scipy because they take forever to build.
    sudo apt-get install -y libasound2-dev libasound2 python3-scipy cmake || exit -1

    #install the python3 dev environment
    sudo apt-get install -y python3-dev || exit -1
    sudo python3 -m pip install --upgrade virtualenv || exit -1

    espeak "installing virtual environment"
    # Rebuilding this is pretty cheap, so just do it every time.
    rm -rf $VENV
    /usr/bin/python3 -m virtualenv --system-site-packages $VENV || exit -1
    PYTHON=$VENV/bin/python3
    espeak "installing virtual environment dependencies"

    $PYTHON -m pip install --ignore-installed psutil flask Flask-WTF pyalsaaudio pydub pyaudio pyyaml dbus-python || exit -1
    #Sometimes pygame tries to install without a whl, and fails (like 2.4.0) this
    #checks that only correct versions will install
    $PYTHON -m pip install --ignore-installed --only-binary ":all:" pygame || exit -1

    espeak "downloading PS move API"
    #install psmoveapi (currently adangert's for opencv 3 support)
    rm -rf psmoveapi
    git clone --recursive https://github.com/thp/psmoveapi.git 
    cd psmoveapi
    git checkout 8a1f8d035e9c82c5c134d848d9fbb4dd37a34b58

    espeak "compiling PS move API components"
    mkdir build
    cd build
    cmake .. \
        -DPSMOVE_BUILD_CSHARP_BINDINGS:BOOL=OFF \
        -DPSMOVE_BUILD_EXAMPLES:BOOL=OFF \
        -DPSMOVE_BUILD_JAVA_BINDINGS:BOOL=OFF \
        -DPSMOVE_BUILD_OPENGL_EXAMPLES:BOOL=OFF \
        -DPSMOVE_BUILD_PROCESSING_BINDINGS:BOOL=OFF \
        -DPSMOVE_BUILD_TESTS:BOOL=OFF \
        -DPSMOVE_BUILD_TRACKER:BOOL=OFF \
        -DPSMOVE_USE_PSEYE:BOOL=OFF
    make -j4
    
    #change the supervisord directory to our own homename
    #this replaces pi default username in joust.conf,
    sed -i -e "s/pi/$HOMENAME/g" $HOMEDIR/JoustMania/conf/supervisor/conf.d/joust.conf
    
    
    #installs custom supervisor script for running joustmania on startup
    sudo cp -r $HOMEDIR/JoustMania/conf/supervisor/ /etc/
    
    #Use amixer to set sound output to 100%
    amixer sset PCM,0 100%
    sudo alsactl store
    
    #This will disable on-board bluetooth with the --disable_internal_bt command line option
    #This will allow only class one long range btdongles to connect to psmove controllers
    if [ "$1" = "--disable_internal_bt" ]; then
	echo "disabling internal bt"
        sudo grep -qxF 'dtoverlay=disable-bt' /boot/config.txt || { echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt; sudo rm -rf /var/lib/bluetooth/*; }
        sudo systemctl disable hciuart || exit -1
    fi

    uname2="$(stat --format '%U' $HOMEDIR'/JoustMania/setup.sh')"
    uname3="$(stat --format '%U' $HOMEDIR'/JoustMania/piparty.py')"
    if [ "${uname2}" = "root" ] || [ "${uname3}" = "root" ] ; then
        sudo chown -R $HOMENAME:$HOMENAME $HOMEDIR/JoustMania/
        espeak "permisions updated, please wait after reboot for Joustmania to start"
    else
        echo "no permissions to update"
    fi
    
    echo "joustmania successfully updated, now rebooting"
    espeak "Joustmania successfully updated, now rebooting"
    # Pause a second before rebooting so we can see all the output from this script.
    (sleep 2; sudo reboot) &
}

setup $1 2>&1 | tee setup.log
