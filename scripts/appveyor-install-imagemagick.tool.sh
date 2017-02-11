#!/bin/bash

ls -lt /c/ProgramData/chocolatey/lib

if [[ ! -e /c/ProgramData/chocolatey/lib/imagemagick.tool ]]
then
    set -x
    appveyor AddMessage "installing chocolatey imagemagick.tool"
    choco install imagemagick.tool
    ls -lt /c/ProgramData/chocolatey/lib
fi
