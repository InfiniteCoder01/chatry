#!/usr/bin/env bash

# you need to install `mingw-w64 build-essential` for this to work
set -e

export LIB_NAME="better_processes"
export EXTENTION_NAME="BetterProcesses"


export EXPORT_DIR="."
# export EXPORT_DIR="TestProject/addons/${EXTENTION_NAME}"
export BUILD_FEATURE_FOR_PROJECT="--features cdylib"


main()
{
    install_target
    compile
}


install_target()
{
    rustup target install ${PLATFORM_LABEL} ${RUSTUP_NIGHTLY}
}


compile()
{
    cargo ${CARGO_NIGHTLY} build --target ${PLATFORM_LABEL} ${CARGO_RELEASE_ARGS} ${BUILD_FEATURE_FOR_PROJECT}
    mkdir -p ${EXPORT_DIR}
    cp ${TARGET_PATH} ./${EXPORT_DIR}/${FILE_NAME}
}


echoVars()
{
    echo PLATFORM_LABEL = ${PLATFORM_LABEL}
    echo CARGO_RELEASE_ARGS = ${CARGO_RELEASE_ARGS}
    echo TARGET_PATH = ${TARGET_PATH}
    echo LIB_NAME = ${LIB_NAME}
}


debugEnv()
{
    export CARGO_RELEASE_ARGS=""
    export TARGET_TYPE_PATH="debug"
    export CARGO_NIGHTLY=""
    export RUSTUP_NIGHTLY=""
    export LIB_APPEND=".debug"
}
releaseEnv()
{
    export CARGO_RELEASE_ARGS="--release"
    export TARGET_TYPE_PATH="release"
    export LIB_APPEND=""
}
nightlyEnv()
{
    export CARGO_NIGHTLY="+nightly"
    export RUSTUP_NIGHTLY="--toolchain nightly"
}
windowsEnv()
{
    #window-gnu target didn't seem to work on Windows, so lets use msvc there
    #(except when on Linux building for Windows)
    if [[ $OS = Windows_NT ]]; then 
        export PLATFORM_LABEL="x86_64-pc-windows-msvc"
    else
        export PLATFORM_LABEL="x86_64-pc-windows-gnu"
    fi
    export FILE_NAME="${LIB_NAME}${LIB_APPEND}.dll"
    export TARGET_PATH="target/${PLATFORM_LABEL}/${TARGET_TYPE_PATH}/${LIB_NAME}.dll"
}
linuxEnv()
{
    export PLATFORM_LABEL="x86_64-unknown-linux-gnu"
    export FILE_NAME="lib${LIB_NAME}${LIB_APPEND}.so"
    export TARGET_PATH="target/${PLATFORM_LABEL}/${TARGET_TYPE_PATH}/lib${LIB_NAME}.so"
}

buildAll()
{
    $SCRIPT --release --windows
    # $SCRIPT --debug --windows
    $SCRIPT --release --linux
    # $SCRIPT --debug --linux
}

createGDExtensionFile()
{
    mkdir -p ${EXPORT_DIR}
cat << EOF > ./${EXPORT_DIR}/$EXTENTION_NAME.gdextension
[gd_resource type="GDExtension"]

[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = 4.1

[libraries]
windows.debug.x86_64 = "./${LIB_NAME}.dll"
windows.release.x86_64 = "./${LIB_NAME}.dll"
linux.debug.x86_64 = "./lib${LIB_NAME}.so"
linux.release.x86_64 = "./lib${LIB_NAME}.so"
EOF
}


args()
{
    debugEnv

    if [[ $OS = Windows_NT ]]; then
        export TARGET="windows"
    else
        export TARGET="linux"
    fi

    while [[ $# -gt 0 ]]
    do
    key="$1"
    case $1 in
        -e|--editor)
            editor
            exit -1
            ;;
        -d|--debug)
            debugEnv
            ;;
        -r|--release)
            releaseEnv
            ;;
        -w|--windows)
            export TARGET="windows"
            ;;
        -l|--linux)
            export TARGET="linux"
            ;;
        -h|--help)
            echoHelp
            exit -1
            ;;
        -s|--sleep)
            sleep 1
            ;;
        -a|--all)
            buildAll
            exit 0
            ;;
        *)
            echo "Arguement Error: $1"
            exit -1
    esac
    shift
    done


    case $TARGET in
        windows)
            windowsEnv
            ;;
        linux)
            linuxEnv
            ;;
        *)
            echo "bad target!"
            return -1
    esac

    
    echoVars
}

echoHelp()
{
cat << EOF
$0 usage:
-d or --debug
    set build to debug (default)
-r or --release
    set build to release
-w or --windows
    set build to Windows
-l or --linux
    set build to Linux
-h or --help
    print this help
EOF
}

ORG_PATH=$(pwd)
cd $(dirname $0)
SCRIPT=$0

args $@

createGDExtensionFile


main
