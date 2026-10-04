#!/bin/bash
# P3 matrix: res x mode x executor, rounds alternating; 100 frames each
cd "$(dirname "$0")"; mkdir -p mx
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_FRAMES=${FR:-100}
for round in 1 2 3; do
for res in 1920:1200 3024:1964; do w=${res%:*}; h=${res#*:}
for n in 16 32; do
for mode in 0 1 2; do
  for ex in gpu cpu12; do
    args=(); [ $ex = cpu12 ] && args=(--gpu off)
    f=mx/m${mode}-${ex}_${w}x${h}_n$((n*n))_r$round
    UI_COLS=$n UI_ROWS=$n UI_W=$w UI_H=$h P3_MODE=$mode perl -e 'alarm 120; exec @ARGV' ./p3 "${args[@]}" > $f.out 2> $f.err
    echo "$(date +%T) $f exit $? load $(sysctl -n vm.loadavg | awk '{print $2}')"
  done
done; done; done; done
