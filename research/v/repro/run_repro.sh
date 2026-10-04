#!/bin/bash
# Repro matrix: 3 alternating rounds of
#   P3 headless (1920x1200, 3024x1964; N=256 cards, 2,000 glyphs; shared bang GPU runtime and --gpu off own device)
#   paced headless probes for the in-window GPU-time question (UI_PACE 8 and 3 ms between frames)
#   framework core, one expression, CPU pool, at 125/500/1250 rows (501/2,001/5,001 elements)
#   real 2x windows (1512x982 pt, 3024x1964 drawable): P3, P2 full redraw, P2 incremental (caret, hover, text column, static), P3 with a private queue
# then two 2,000-frame core runs for the frame-cost trend.
cd "$(dirname "$0")"; mkdir -p mx win cmx logs
export BEND_NO_TELEMETRY=1
LOG=logs/run_repro.log
r() { # tag outdir timeout cmd...
  local tag=$1 dir=$2 to=$3; shift 3
  perl -e "alarm $to; exec @ARGV" "$@" > $dir/${tag}_r$round.out 2> $dir/${tag}_r$round.err
  echo "$(date +%T) $tag r$round exit $? load $(sysctl -n vm.loadavg | awk '{print $2}')" | tee -a $LOG
}
echo "$(date +%T) start uptime: $(uptime)" | tee -a $LOG
for round in 1 2 3; do
  for res in 1920:1200 3024:1964; do w=${res%:*}; h=${res#*:}
    UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16 UI_W=$w UI_H=$h UI_FRAMES=100 P3_MODE=0 r p3-gpu_${w}x${h} mx 120 p3/p3
    UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16 UI_W=$w UI_H=$h UI_FRAMES=100 P3_MODE=0 r p3-cpu12_${w}x${h} mx 120 p3/p3 --gpu off
  done
  UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16 UI_W=3024 UI_H=1964 UI_FRAMES=100 UI_PACE=8 P3_MODE=0 r p3pace8-cpu12_3024x1964 mx 120 p3/p3pace --gpu off
  UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16 UI_W=3024 UI_H=1964 UI_FRAMES=100 UI_PACE=3 P3_MODE=0 r p3pace3-cpu12_3024x1964 mx 120 p3/p3pace --gpu off
  for rows in 125 500 1250; do
    UI_ROWS=$rows UI_FRAMES=110 UI_ONE=1 UI_BANG=0 r one-cpu12-$rows cmx 200 core/core --gpu off
  done
  export UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16 UI_W=3024 UI_H=1964 UI_FRAMES=120
  P3_MODE=0 r p3w win 120 p3/p3win
  UI_MODE=1 UI_SCEN=1 r hash-full-cpu12 win 120 dirty/dirtywp --gpu off
  for sc in 2 1 3 0; do UI_MODE=2 UI_SCEN=$sc r hash-inc-s$sc-cpu12 win 120 dirty/dirtywp --gpu off; done
  P3_MODE=0 P3_OWNQ=1 r p3w-ownq win 120 p3/p3win
  unset UI_GLYPHS UI_COLS UI_ROWS UI_W UI_H UI_FRAMES
done
round=long
UI_ROWS=500 UI_FRAMES=2000 UI_ONE=1 UI_BANG=0 r one-cpu12-500 cmx 300 core/core --gpu off
UI_ROWS=1250 UI_FRAMES=2000 UI_ONE=1 UI_BANG=0 r one-cpu12-1250 cmx 300 core/core --gpu off
echo "$(date +%T) end uptime: $(uptime)" | tee -a $LOG
