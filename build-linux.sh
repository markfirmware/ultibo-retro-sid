#!/bin/bash

# build and test on linux or windows git bash

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

function unix_line_endings {
    tr -d \\r < $1 > tmp && \
    mv tmp $1
}

function convert-frames {
    convert-frames-by-size 1024x768
    convert-frames-by-size 1920x1080
    convert-frames-by-size 1920x1200
}

function convert-frames-by-size {
    local SIZE=$1
    local FRAMES=run-qemu-output/frame*-${SIZE}x3.fb
    ls $FRAMES > /dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        for frame in $FRAMES
        do
            ultibo-bash convert -size $SIZE -depth 8 rgb:$frame ${frame%.fb}.png && \
            rm $frame
        done
    fi
}

function test-qemu-target {
    echo .... running qemu
    local RESTORE_PWD=$(pwd)
    local FOLDER=$1
    cd $FOLDER/$OUTPUT && \
    \
    time python $RESTORE_PWD/run-qemu
    if [[ $? -ne 0 ]]; then log fail: $?; fi

    for textfile in run-qemu-output/*.txt
    do
        unix_line_endings $textfile
    done
    sed -i 's/.\x1b.*\x1b\[D//' run-qemu-output/qemumonitor.txt
    sed -i 's/\x1b\[K//' run-qemu-output/qemumonitor.txt
    ls run-qemu-output/screen*.ppm > /dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        for screen in run-qemu-output/screen*.ppm
        do
            ultibo-bash convert $screen ${screen%.ppm}.png && \
            rm $screen
        done
    fi
    convert-frames

    file run-qemu-output/*

#   grep -i error run-qemu-output/applog.txt	
#   local EXIT_STATUS=$?

    cd $RESTORE_PWD
#   if [[ EXIT_STATUS == 0 ]]; then log fail: $?; fi
}

function build-ultibo-retro-sid {
    build-as RPi3 . markfirmware/ultibo-retro-sid/circleci-2.0 Project1.pas
    build-as QEMU . markfirmware/ultibo-retro-sid/circleci-2.0 Project1.pas
}

function build-lpr {
    local LPR_FILE=$1
    local TARGET_COMPILER_OPTIONS=$2
    local CFG_NAME=$3
    local LPR_FOLDER=$4
    local PLATFORM_SYMBOL=$5
    local INCLUDES=-Fi/root/ultibo/core/fpc/source/packages/fv/src
    log .... building $LPR_FILE
    rm -rf $LPR_FOLDER/obj && \
    mkdir -p $LPR_FOLDER/obj && \
    ultibo-bash fpc \
     -d$PLATFORM_SYMBOL \
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
     @/root/ultibo/core/fpc/bin/$CFG_NAME \
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
                    build-lpr $LPR_FILE "-CpARMV7A -WpQEMUVPB" qemuvpb.cfg $FOLDER TARGET_QEMUARM7A
                    test-qemu-target $FOLDER ;;
                RPi)
                    build-lpr $LPR_FILE "-CpARMV6 -WpRPIB" rpi.cfg $FOLDER TARGET_RPI_INCLUDING_RPI0 ;;
                RPi2)
                    build-lpr $LPR_FILE "-CpARMV7A -WpRPI2B" rpi2.cfg $FOLDER TARGET_RPI2_INCLUDING_RPI3 ;;
                RPi3)
                    build-lpr $LPR_FILE "-CpARMV7A -WpRPI3B" rpi3.cfg $FOLDER TARGET_RPI3 ;;
            esac
#           local THISOUT=$OUTPUT/kernels-and-tests/$FOLDER
#           rm -rf $THISOUT && \
#           mkdir -p $THISOUT && \
#           cp -a $FOLDER/$OUTPUT/* $THISOUT && \
#           if [[ $? -ne 0 ]]; then log fail: $?; fi
        fi
    fi
}

function create-build-summary {
    cat $LOG | egrep -i '(fail|error|warning|note):' | sort | uniq > $ERRORS
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
SCREEN_NUMBER=1
ERRORS=$OUTPUT/build-errors.txt
LOG=$OUTPUT/build.log
rm -rf $OUTPUT
mkdir -p $OUTPUT
rm -f $LOG

build-ultibo-retro-sid

create-build-summary
