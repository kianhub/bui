#!/bin/bash
# 20k-frame drift: drift4 (text + String-keyed Map per frame) then the v/measure control (cull-cpu12, numeric scene)
cd "$(dirname "$0")"
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_PACE=0 UI_COLS=16 UI_ROWS=16 UI_W=1920 UI_H=1200 UI_FRAMES=${FRAMES:-20000} UI_BLIT=1 UI_MODE=0 UI_CELLS=133 UI_KEYS=200
( while true; do echo "$(date +%H:%M:%S) load $(sysctl -n vm.loadavg | awk '{print $2}') gpu $(ioreg -r -d 1 -c IOAccelerator 2>/dev/null | grep -oE '"Device Utilization %"=[0-9]+' | head -1 | grep -oE '[0-9]+$')"; sleep 2; done ) > load.log &
lp=$!
echo "start $(date +%T) load $(sysctl -n vm.loadavg)"
perl -e 'alarm 900; exec @ARGV' ./drift4 --gpu off > d4.out 2> d4.err; echo "drift4 done $(date +%T) exit $? load $(sysctl -n vm.loadavg)"
perl -e 'alarm 900; exec @ARGV' ../../measure/ui_blit --gpu off > ctl.out 2> ctl.err; echo "control done $(date +%T) exit $? load $(sysctl -n vm.loadavg)"
kill $lp
