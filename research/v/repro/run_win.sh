#!/bin/bash
# real windows at 2x (PR #1108 window.c): 1512x982 pt window, 3024x1964 drawable; 120 frames, 3 alternating rounds
cd "$(dirname "$0")"; mkdir -p win
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16 UI_W=3024 UI_H=1964 UI_FRAMES=120
r() { local tag=$1; shift; perl -e 'alarm 120; exec @ARGV' "$@" > win/${tag}_r$round.out 2> win/${tag}_r$round.err; echo "$(date +%T) $tag r$round exit $? load $(sysctl -n vm.loadavg | awk '{print $2}')"; }
for round in 1 2 3; do
  P3_MODE=0 r p3w p3/p3win
  UI_MODE=1 UI_SCEN=1 r hash-full-cpu12 dirty/dirtywp --gpu off
  for sc in 0 1 2 3; do UI_MODE=2 UI_SCEN=$sc r hash-inc-s$sc-cpu12 dirty/dirtywp --gpu off; done
  UI_MODE=1 UI_SCEN=1 r tree-full-cpu12 dirty/dirtyw --gpu off
  for sc in 1 2 3; do UI_MODE=2 UI_SCEN=$sc r tree-inc-s$sc-cpu12 dirty/dirtyw --gpu off; done
done
