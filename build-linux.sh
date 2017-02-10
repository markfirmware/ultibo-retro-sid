#!/bin/bash
echo
# build and test on linux

function log {
    echo $* | tee -a $LOG
}

function build-ultibo-retro-sid {
    build-as RPi3 . Project1.pas
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
    fpc \
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
    local LPR_FILE=$3
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
                    build-lpr $LPR_FILE "-CpARMV7A -WpQEMUVPB" qemuvpb.cfg $FOLDER TARGET_QEMUARM7A ;;
                RPi)
                    build-lpr $LPR_FILE "-CpARMV6 -WpRPIB" rpi.cfg $FOLDER TARGET_RPI_INCLUDING_RPI0 ;;
                RPi2)
                    build-lpr $LPR_FILE "-CpARMV7A -WpRPI2B" rpi2.cfg $FOLDER TARGET_RPI2_INCLUDING_RPI3 ;;
                RPi3)
                    build-lpr $LPR_FILE "-CpARMV7A -WpRPI3B" rpi3.cfg $FOLDER TARGET_RPI3 ;;
            esac
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
ERRORS=$OUTPUT/build-errors.txt
LOG=$OUTPUT/build.log
rm -rf $OUTPUT
mkdir -p $OUTPUT
rm -f $LOG

build-ultibo-retro-sid

create-build-summary
