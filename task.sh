
err_report() {
    echo "Error on line $2:$1"
    echo "Stopping the script $(basename "$3")."
}
FILENAME="$(echo $(cd $(dirname "$BASH_SOURCE") && pwd -P)/$(basename "$BASH_SOURCE"))"
RUNNINGSCRIPT="$0"
trap 'err_report $LINENO $FILENAME $RUNNINGSCRIPT; exit 1' ERR

check_core(){
    if [ -e core ]; then
	echo bt | gdb choreonoid core
        size=$(stat -c %s core)
        if [ $size -gt 10000000000 ]; then
            rm -rf core
        fi
    fi
    cp ${PREFIX}/share/robot-sources.tar.bz2 ${WORKSPACE} || true
    mv *.bz2 ${WORKSPACE} || true
    mv *.log  ${WORKSPACE} || true
}

trap check_core EXIT

PROJECT=${1}
TASK=${2}
AUTOPOSX=${3}
AUTOPOSY=${4}
OKPOSX=${5}
OKPOSY=${6}
WAIT=${7}
TARGET=${8}
PORT=${9}

export ASAN_OPTIONS="disable_coredump=0:unmap_shadow_on_exit=1:abort_on_error=1"
# Report, but don't fail on, leaks in program samples during test.
export LSAN_OPTIONS="exitcode=0"
if [ "$(lsb_release -rs)" = "14.04" ]; then
    ASAN_LIB=/usr/lib/x86_64-linux-gnu/libasan.so.0
elif [ "$(lsb_release -rs)" = "16.04" ]; then
    ASAN_LIB=/usr/lib/x86_64-linux-gnu/libasan.so.2
else
    ASAN_LIB=/usr/lib/x86_64-linux-gnu/libasan.so.4
fi
ulimit -c unlimited
killall -9 openhrp-model-loader || true
kill -9 `pidof choreonoid` &> /dev/null || true
killall -9 recordmydesktop || true
cd ${PREFIX}/share/hrpsys/samples/${PROJECT}
rm -f core core*.bz2
rm -f task_result.txt drc.py_start.txt drc.py_end.txt
rm -rf PointCloud
rm -f *.tau
rm -f *.qRef
rm -f *.log
rm -f /tmp/emg-hmc_*.log /tmp/motion-command-solver_*.log /tmp/walking-command-solver_*.log
./clear-omninames.sh

if type savedbg-hrp > /dev/null 2>&1
then
    SAVEDBG_HRP=savedbg-hrp
else
    SAVEDBG_HRP=
fi

$SAVEDBG_HRP LD_PRELOAD="${ASAN_LIB}:${PREFIX}/lib/libtrap_fpe.so" CNOID_TASK_TRY_FULL_AUTO_MODE=1 choreonoid ${TASK}.cnoid --start-simulation &
CHOREONOID=$(jobs -p %+)

for ((i=0; i<900; i++)); do
    if [ -e drc.py_start.txt ]; then
	echo "beginning of drc.py is detected at $i[s]"
	break
    fi
    c=`ps -ef | grep choreonoid | grep -v grep | wc -l`
    if [ $c = 0 ]; then
        echo "choreonoid died"
        exit 1
    fi
    echo "waiting for beginning of drc.py: $i[s]"
    sleep 1
done
if [ $i == 900 ]; then
    echo "drc.py didn't start in 900[s]"
    exit 1
fi

WINDOWSID=$(xwininfo -display :0 -name "${TASK} - Choreonoid" | grep 'id: 0x' | grep -Eo '0x[a-z0-9]+')

recordmydesktop --windowid ${WINDOWSID} --display :0 --no-sound --overwrite -o ${WORKSPACE}/task.ogv 2>&1 > /dev/null &
RECORDMYDESKTOP=$(jobs -p %+)

for ((i=0; i<900; i++)); do
    if [ -e drc.py_end.txt ]; then
	echo "ending of drc.py is detected at $i[s]"
	break
    fi
    c=`ps -ef | grep choreonoid | grep -v grep | wc -l`
    if [ $c = 0 ]; then
        echo "choreonoid died"
        exit 1
    fi
    echo "waiting for ending of drc.py: $i[s]"
    sleep 1
done
if [ $i == 900 ]; then
    echo "drc.py didn't finish in 900[s]"
    exit 1
fi

if [ -e ${WORKSPACE}/drcutil/.jenkins/${TASK}-setTargetPos.py ]; then
    python ${WORKSPACE}/drcutil/.jenkins/${TASK}-setTargetPos.py
fi

if [ "$(lsb_release -rs)" != "16.04" ]; then
    FREE_BEFORE=$(free -m | awk 'NR==3 { print $3 }')
else
    FREE_BEFORE=$(free -m | awk 'NR==2 { print $7 }')
fi
PS_BEFORE=$(ps -F $CHOREONOID | awk 'NR==2 { print $6 }')
echo "PS_BEFORE=$PS_BEFORE"

xte -x :0 "mousemove ${AUTOPOSX} ${AUTOPOSY}" && xte "mouseclick 1"
sleep 1
xte -x :0 "mousemove ${OKPOSX} ${OKPOSY}" && xte "mouseclick 1"

for ((i=0; i<${WAIT}; i++)); do
    if [ -e task_result.txt ]; then
	echo "task completion is detected at $i[s]"
	mv *.tau *.q *.qRef ${WORKSPACE} || true
	break
    fi
    c=`ps -ef | grep choreonoid | grep -v grep | wc -l`
    if [ $c = 0 ]; then
        echo "choreonoid died"
        exit 1
    fi
    sleep 1
done
HMC_LOGS=`ls /tmp/emg-hmc_*.log /tmp/motion-command-solver_*.log /tmp/walking-command-solver_*.log || true`
if [ "$HMC_LOGS" != "" ]; then
    tar jcf ${WORKSPACE}/hmc_log.tar.bz2 $HMC_LOGS || true
fi

PS_AFTER=$(ps -F $CHOREONOID | awk 'NR==2 { print $6 }')
echo "PS_AFTER=$PS_AFTER"
if [ "$(lsb_release -rs)" != "16.04" ]; then
    FREE_AFTER=$(free -m | awk 'NR==3 { print $3 }')
else
    FREE_AFTER=$(free -m | awk 'NR==2 { print $7 }')
fi
if [ "$PS_BEFORE" != "" ] && [ "$PS_AFTER" != "" ]; then
    PS_CHANGE=$(( $PS_AFTER - $PS_BEFORE ))
    echo 'used,change' > $WORKSPACE/choreonoid.csv
    echo $PS_AFTER,$PS_CHANGE >> $WORKSPACE/choreonoid.csv
fi
if [ "$FREE_BEFORE" != "" ] && [ "$FREE_AFTER" != "" ]; then
    echo FREE_BEFORE=$FREE_BEFORE
    echo FREE_AFTER=$FREE_AFTER
    FREE_CHANGE=$(( $FREE_AFTER - $FREE_BEFORE ))
    echo 'used,change' > $WORKSPACE/system.csv
    echo $FREE_AFTER,$FREE_CHANGE >> $WORKSPACE/system.csv
fi

#import -display :0 -window ${WINDOWSID} ${WORKSPACE}/task.png 2>&1 > /dev/null
gnome-screenshot -w -f ${WORKSPACE}/task.png
kill -2 $RECORDMYDESKTOP || true

RESULT="OK"

if [ -e task_result.txt ]; then
    ret=`cat task_result.txt`
    if [ "${ret}" = "interrupted" ];then
        RESULT="STOP"
    fi
else
    RESULT="TIMEOUT"
fi

if [ -e ${WORKSPACE}/drcutil/.jenkins/${TASK}-checkRobotPos.py ]; then
    python ${WORKSPACE}/drcutil/.jenkins/getRobotPos.py | tee ${WORKSPACE}/${TASK}-getRobotPos.txt
    ROBOT_POS=$(cat ${WORKSPACE}/${TASK}-getRobotPos.txt | tail -3 | python ${WORKSPACE}/drcutil/.jenkins/${TASK}-checkRobotPos.py)
    echo "Robot: ${ROBOT_POS}"
    if [ "${ROBOT_POS}" = "FALL" ]; then
        RESULT=${ROBOT_POS}
    fi
fi

if [ "${RESULT}" = "OK" ] && [ "${TARGET}" != "" ]; then
  python ${WORKSPACE}/drcutil/.jenkins/getTargetPos.py ${TARGET} ${PORT} | tee ${WORKSPACE}/${TASK}-getTargetPos.txt
  RESULT=$(cat ${WORKSPACE}/${TASK}-getTargetPos.txt | tail -2 | python ${WORKSPACE}/drcutil/.jenkins/${TASK}-checkTargetPos.py ${VR})
  echo "Target: ${RESULT}"
fi

if [ "${RESULT}" = "OK" ] && [ -e ${WORKSPACE}/*.qRef ]; then
    if [ "${PROJECT}" == "HRP5P" ]; then
        BLACKLIST="HP:motor_joint HY:motor_joint WY:motor_joint RCY:LCY"
    else
        BLACKLIST="RARM_JOINT6:LHAND_JOINT0"
    fi
    hrpsys-self-collision-checker ${PREFIX}/share/OpenHRP-3.1/robot/${PROJECT}/model/${PROJECT}main.wrl ${WORKSPACE}/*.qRef ${BLACKLIST} > ${WORKSPACE}/SelfCollision.txt || true
    if [ -s ${WORKSPACE}/SelfCollision.txt ]; then
	RESULT="SCOL"
	echo "SelfCollision: ${RESULT}"
    fi
fi

RED=$(convert ${WORKSPACE}/task.png -format %c histogram:info: | grep red | cut -d: -f 1 | sed -e "s/ //g")
echo "Red: ${RED}"
if [ -n "${RED}" ] && [ ${RED} -gt 300000 ]; then
    EMA="EMERGENCY"
else
    EMA="NORMAL"
fi
echo "EMA: ${EMA}"

kill -9 $CHOREONOID || true

wait $RECORDMYDESKTOP || true
wait $CHOREONOID || true

echo ${RESULT} > ${WORKSPACE}/task_result.txt

JUNIT=${WORKSPACE}/${TASK}.xml
echo "<testsuite tests='1'>" > ${JUNIT}
if [ "${RESULT}" = "OK" ] && [ "${EMA}" = "NORMAL" ]; then
    echo "<testcase name='${TASK}' classname='choreonoid' />" >> ${JUNIT}
else
    echo "<testcase name='${TASK}' classname='choreonoid'><failure message='${RESULT}'>${EMA}</failure></testcase>" >> ${JUNIT}
fi
echo "</testsuite>" >> ${JUNIT}
