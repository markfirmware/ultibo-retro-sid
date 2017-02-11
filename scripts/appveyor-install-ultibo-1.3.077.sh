#!/bin/bash

ULTIBO_VERSION=1.3.077
ULTIBO_RTL_VERSION=1.3.077
ULTIBO_SOURCE=/c/Ultibo/Core/fpc/3.1.1/source

if [[ ! -e /c/Ultibo ]]
then
    set -x
    appveyor AddMessage "installing ultibo $ULTIBO_VERSION"
    curl -fsSL -o ultibo-installer.exe https://github.com/ultibohub/Core/releases/download/$ULTIBO_VERSION/Ultibo-Core-$ULTIBO_VERSION-Cucumber.exe
    ./ultibo-installer //verysilent
    du -sk /c/Ultibo/Core
    rm    /c/Ultibo/Core/laz*
    rm    /c/Ultibo/Core/startlazarus.exe
    rm -r /c/Ultibo/Core/components
    rm -r /c/Ultibo/Core/docs
    rm -r /c/Ultibo/Core/examples
    rm -r /c/Ultibo/Core/firmware
    rm -r /c/Ultibo/Core/fpc/3.1.1/units/armv8-ultibo
    rm -r /c/Ultibo/Core/languages
    rm -r /c/Ultibo/Core/tools
    du -sk /c/Ultibo/Core/fpc/3.1.1/*/*
    du -sk /c/Ultibo

    if [[ "$ULTIBO_RTL_VERSION" == "$ULTIBO_VERSION" ]]
    then
        appveyor AddMessage "(skipped) building ultibo rtl using __buildrtl.bat from $ULTIBO_RTL_VERSION"
    else
        appveyor AddMessage "building ultibo rtl using __buildrtl.bat from $ULTIBO_RTL_VERSION"
        curl -fsSL -o ultibo-rtl-update.zip https://github.com/ultibohub/Core/archive/master.zip
        ls *.zip

        appveyor AddMessage "extracting ultibo rtl source"
        7z x -oultibo-rtl-update ultibo-rtl-update.zip
        ls ultibo-rtl-update/Core-master/source/rtl/ultibo
    
        appveyor AddMessage "moving ultibo rtl source into ultibo core folder"
        ls $ULTIBO_SOURCE/rtl/ultibo
        rm -rf $ULTIBO_SOURCE/rtl/ultibo
        cp -a ultibo-rtl-update/Core-master/source/rtl/ultibo $ULTIBO_SOURCE/rtl/ultibo
        ls $ULTIBO_SOURCE/rtl/ultibo

        appveyor AddMessage "compiling ultibo rtl"
        cd $ULTIBO_SOURCE
        cmd //c __buildrtl.bat
        cd $APPVEYOR_BUILD_FOLDER
    fi

#   du -sk /c/Ultibo
#   /usr/bin/mv /c/Ultibo/Core/fpc/3.1.1/source/packages/fv packages-fv
#   rm -r /c/Ultibo/Core/fpc/3.1.1/source
#   mkdir -p /c/Ultibo/Core/fpc/3.1.1/source/packages
#   /usr/bin/mv packages-fv /c/Ultibo/Core/fpc/3.1.1/source/packages/fv
#   du -sk /c/Ultibo

    appveyor AddMessage "ultibo installation complete"
fi
