#!/bin/bash
# Gap 1 matrix: rows 125/500/1250 (501/2001/5001 elements); 110 frames (first 10 dropped); 3 alternating rounds
cd "$(dirname "$0")"; mkdir -p mx
export BEND_NO_TELEMETRY=1
r() { local tag=$1 fr=$2; shift 2; UI_FRAMES=$fr perl -e 'alarm 200; exec @ARGV' "$@" > mx/${tag}_r$round.out 2> mx/${tag}_r$round.err; echo "$(date +%T) $tag r$round exit $? load $(sysctl -n vm.loadavg | awk '{print $2}')"; }
for round in 1 2 3; do
  for rows in 125 500 1250; do
    export UI_ROWS=$rows
    UI_ONE=0 UI_BANG=0 r staged-cpu12-$rows 110 ./core --gpu off
    UI_ONE=0 UI_BANG=0 r staged-default-$rows 110 ./core
    UI_ONE=1 UI_BANG=0 r one-cpu12-$rows 110 ./core --gpu off
    UI_ONE=1 UI_BANG=0 r one-default-$rows 110 ./core
    UI_ONE=1 UI_BANG=0 r one-cpu1-$rows 110 ./core --gpu off --threads 1
    [ $round = 1 ] && UI_ONE=0 UI_BANG=1 r staged-layoutbang-$rows 30 ./core
    [ $round = 1 ] && UI_ONE=1 UI_BANG=1 r one-bang-$rows 30 ./core
  done
done
