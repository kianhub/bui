#!/bin/bash
# default lane with a bang-free binary (no def is marked as a bang)
cd "$(dirname "$0")"; mkdir -p mx
export BEND_NO_TELEMETRY=1
r() { local tag=$1 fr=$2; shift 2; UI_FRAMES=$fr perl -e 'alarm 200; exec @ARGV' "$@" > mx/${tag}_r$round.out 2> mx/${tag}_r$round.err; echo "$(date +%T) $tag r$round exit $? load $(sysctl -n vm.loadavg | awk '{print $2}')"; }
for round in 1 2 3; do
  for rows in 125 500 1250; do
    export UI_ROWS=$rows
    UI_ONE=0 r staged-nbdefault-$rows 110 ./core_nb
    UI_ONE=1 r one-nbdefault-$rows 110 ./core_nb
    UI_ONE=1 r one-nbcpu12-$rows 110 ./core_nb --gpu off
  done
done
