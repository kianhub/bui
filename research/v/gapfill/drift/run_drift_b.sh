#!/bin/bash
cd "$(dirname "$0")"
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_PACE=0 UI_COLS=16 UI_ROWS=16 UI_W=1920 UI_H=1200 UI_FRAMES=${FRAMES:-20000} UI_BLIT=1 UI_MODE=0 UI_CELLS=133 UI_KEYS=200 UI_RUNS=4096 UI_RUNDEPTH=0
( while true; do echo "$(date +%H:%M:%S) load $(sysctl -n vm.loadavg | awk '{print $2}')"; sleep 2; done ) > loadb.log &
lp=$!
echo "start $(date +%T) load $(sysctl -n vm.loadavg)"
perl -e 'alarm 900; exec @ARGV' ./drift4b --gpu off > d4b.out 2> d4b.err; echo "drift4b done $(date +%T) exit $? load $(sysctl -n vm.loadavg)"
kill $lp
