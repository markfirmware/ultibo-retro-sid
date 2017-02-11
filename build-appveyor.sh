#!/bin/bash

#INSTALL_PATH=/root/ultibo/core/fpc/bin/
INSTALL_PATH=/c/Ultibo/Core/fpc/3.1.1/bin/i386-win32
PATH=$INSTALL_PATH:$PATH

# Build the ultibo projects in this repo.
#
# Runs on linux/x64 with either ultibo installed or docker installed.
# Runs on windows git bash with ultibo installed.
# Runs on windows 10 pro git bash with docker installed.

function log {
    echo $* | tee -a $LOG
}

function ultibo-bash-quotation {
    if [ "$(which $1)" != "" ]
    then
        echo -n $*
    else
        local DOCKER_IMAGE=markfirmware/ultibo-bash
        echo -en "docker run --rm -i -v $(pwd):/workdir --entrypoint /bin/bash $DOCKER_IMAGE -c \"$*\""
    fi
}

function ultibo-bash {
    eval $(ultibo-bash-quotation $*)
}

#function intr {
#    echo $* >> $QEMU_SCRIPT
#}

#function qemu {
#    intr echo $*
#}

#function screendump {
#    qemu screendump screen-$(printf "%02d" $SCREEN_NUMBER).ppm
#    ((SCREEN_NUMBER+=1))
#}

#function make-qemu-script {
#    touch $QEMU_SCRIPT
#\
#    intr sleep 2
#    qemu -en \\\\001c
#    screendump
#    intr sleep 2
#    screendump
#    qemu quit
#\
#    chmod u+x $QEMU_SCRIPT
#}

#function run-qemu {
#    echo .... running qemu
#    QEMU=$(ultibo-bash-quotation qemu-system-arm \
#     -M versatilepb \
#     -cpu cortex-a8 \
#     -kernel kernel.bin \
#     -m 256M \
#     -display none \
#     -serial mon:stdio)
#    eval "./$QEMU_SCRIPT | $QEMU > raw.log 2>&1" && \
#    cat raw.log | egrep -iv '^(alsa|pulseaudio:|audio:)' > serial.log
#}

function unix_line_endings {
    local FILE=$1
    tr -d \\r < $FILE > tmp && \
    echo mv command is from fpc? $(which mv)
    /usr/bin/mv tmp $FILE
}

function test-qemu-target {
    log .... running qemu
    local RESTORE_PWD=$(pwd)
    local FOLDER=$1
    local QEMU_OUTPUT=$FOLDER/$OUTPUT/run-qemu-output
    cd $FOLDER/$OUTPUT && \
    \
#   make-qemu-script && \
#   run-qemu
    time python $RESTORE_PWD/run-qemu
    if [[ $? -ne 0 ]]; then log fail: $?; fi
    cd $RESTORE_PWD

    unix_line_endings $QEMU_OUTPUT/monitor.txt
    unix_line_endings $QEMU_OUTPUT/serial0.txt
    unix_line_endings $QEMU_OUTPUT/serial1.txt
    unix_line_endings $QEMU_OUTPUT/serial2.txt
    unix_line_endings $QEMU_OUTPUT/serial3.txt

    sed -i 's/.\x1b.*\x1b\[D//' $QEMU_OUTPUT/monitor.txt
    sed -i 's/\x1b\[K//' $QEMU_OUTPUT/monitor.txt

    ls $QEMU_OUTPUT/screen*.ppm > /dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        for screen in $QEMU_OUTPUT/screen*.ppm
        do
#           local CONVERT=ultibo-bash convert
            local CONVERT=/c/ProgramData/chocolatey/lib/imagemagick.tool/tools/convert.exe
            $CONVERT $screen ${screen%.ppm}.png && \
            rm $screen
        done
    fi

    file $QEMU_OUTPUT/*

    grep -i error $QEMU_OUTPUT/applog.txt	
    local EXIT_STATUS=$?

    if [[ EXIT_STATUS == 0 ]]; then log fail: $?; fi
}

function build-example {
    TARGETS_PATH=$1
    if [[ -d $TARGETS_PATH ]]
    then
        for TARGET_PATH in $TARGETS_PATH/*
        do
            build-as $(basename $TARGET_PATH) $TARGET_PATH ultibohub/Examples
        done
    fi
}

function build-asphyre {
    local SAMPLES_PATH=gh/ultibohub/Asphyre/Samples/FreePascal/Ultibo
    for SAMPLE_PATH in $SAMPLES_PATH/*
    do
        build-as RPi2 $SAMPLE_PATH ultibohub/Asphyre
    done
}

function build-demo {
    DEMO_PATH=gh/ultibohub/Demo
    for TARGET in RPi RPi2 RPi3
    do
        mkdir -p $DEMO_PATH/$TARGET
        build-as $TARGET $DEMO_PATH/$TARGET ultibohub/Demo "$DEMO_PATH/UltiboDemo$TARGET.lpr"
    done
}

function build-examples {
    local EXAMPLES_PATH=gh/ultibohub/Examples
    for EXAMPLE in $EXAMPLES_PATH/[0-9][0-9]-*
    do
        build-example $EXAMPLE
    done
    for EXAMPLE in $EXAMPLES_PATH/Advanced/*
    do
        build-example $EXAMPLE
    done
}

function build-lpr {
    local LPR_FILE=$1
    local TARGET_COMPILER_OPTIONS=$2
    local CFG_NAME=$3
    local LPR_FOLDER=$4
    local INCLUDES=-Fi/c/Ultibo/Core/fpc/3.1.1/source/packages/fv/src
    log .... building $LPR_FILE
    rm -rf $LPR_FOLDER/obj && \
    mkdir -p $LPR_FOLDER/obj && \
    ultibo-bash fpc \
     -l- \
     -v0ewn \
     -B \
     -Tultibo \
     -O2 \
     -Parm \
     -Mdelphi \
     -FuSource \
     -Fugh/ultibohub/Asphyre/Source \
     -FE$LPR_FOLDER/obj \
     $INCLUDES \
     $TARGET_COMPILER_OPTIONS \
     @$INSTALL_PATH/$CFG_NAME \
     $LPR_FILE |& tee -a $LOG && \
\
    mv kernel* $LPR_FOLDER/$OUTPUT
    if [[ $? -ne 0 ]]; then log fail: $?; fi
}

function build-as {
    local TARGET=$1
    local FOLDER=$2
    local REPO=$3
    local LPR_FILE=$4
    if [[ -d $FOLDER ]]
    then
        if [[ $LPR_FILE == "" ]]
        then
            ls $FOLDER/*.lpr > /dev/null 2>&1
            if [[ $? -eq 0 ]]
            then
                local LPR_FILE=$FOLDER/*.lpr
            fi
        fi
        if [[ $LPR_FILE != "" ]]
        then
            rm -rf $FOLDER/$OUTPUT
            mkdir -p $FOLDER/$OUTPUT
            case $TARGET in
                QEMU)
                    build-lpr $LPR_FILE "-CpARMV7A -WpQEMUVPB" qemuvpb.cfg $FOLDER
                    ;; # test-qemu-target $FOLDER ;;
                RPi)
                    build-lpr $LPR_FILE "-CpARMV6 -WpRPIB" rpi.cfg $FOLDER ;;
                RPi2)
                    build-lpr $LPR_FILE "-CpARMV7A -WpRPI2B" rpi2.cfg $FOLDER ;;
                RPi3)
                    build-lpr $LPR_FILE "-CpARMV7A -WpRPI3B" rpi3.cfg $FOLDER ;;
            esac
            local THISOUT=$OUTPUT/kernels-and-tests/$FOLDER
            rm -rf $THISOUT && \
            mkdir -p $THISOUT && \
            cp -a $FOLDER/$OUTPUT/* $THISOUT && \
            if [[ $? -ne 0 ]]; then log fail: $?; fi
        fi
    fi
}

function create-build-summary {
    cat $LOG | egrep -i '(fail|fatal|error|warning|note):' | sort | uniq > $ERRORS
    log
    log Summary:
    log
    cat $ERRORS | tee -a $LOG
    log
    log $(wc $ERRORS)
    if [[ -s $ERRORS ]]
    then
        exit 1
    fi
}

OUTPUT=build-output
QEMU_SCRIPT=run-qemu.tmp
SCREEN_NUMBER=1
ERRORS=build-errors.txt
LOG=$OUTPUT/build.log
rm -rf $OUTPUT
mkdir -p $OUTPUT
rm -f $LOG

python -m pip install parse

build-examples
build-asphyre
build-demo

create-build-summary
