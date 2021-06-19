#!/usr/bin/env bash

source config.sh
source packsrc.sh
FILENAME="$(echo $(cd $(dirname "$BASH_SOURCE") && pwd -P)/$(basename "$BASH_SOURCE"))"
RUNNINGSCRIPT="$0"
trap 'err_report $LINENO $FILENAME $RUNNINGSCRIPT; exit 1' ERR
set -E -o pipefail

export LSAN_OPTIONS="exitcode=0"

cd $SRC_DIR

echo "drcutil headSHA" | tee $SRC_DIR/headSHA.log

getSHA() {
    dir_name=$1
    if [ -e $dir_name ]; then
        cd "$dir_name/"
        echo -n "$dir_name  ...  " | tee -a $SRC_DIR/headSHA.log
        sha=$(git show -s --format=%H)
        branch=$(git branch | grep \* | cut -d ' ' -f2)
         
        echo -n "$branch  ...  $sha" | tee -a $SRC_DIR/headSHA.log
        
        if [[ $(git diff --stat) != '' ]]; then
          echo -n '  ... dirty' | tee -a $SRC_DIR/headSHA.log
        fi
        #insert new line
        echo  | tee -a $SRC_DIR/headSHA.log 
        
        if [ $dir_name == "choreonoid" ]; then
            cd  ext
            getSHA hrpcnoid
            getSHA cnoid-boost-python
            getSHA grxui-plugin
            getSHA openhrp-plugin
            cd ../
        fi
        cd ../
    fi
}

built_dirs=
if [ ! $# -eq 0 ]; then
    PACKAGES=$@
fi

for package in $PACKAGES; do
    getSHA $package
done

# if [ $# = 0 ]; then
#     packsrc $built_dirs
#     $SUDO mv robot-sources.tar.bz2 $PREFIX/share/
# fi
