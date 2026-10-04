#!/bin/bash
# Gap 2 matrix at 3024x1964, N=256 cards, 2000 16x32 8-bit glyphs; 3 alternating rounds x 40 frames
cd "$(dirname "$0")"; mkdir -p mx
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16 UI_W=3024 UI_H=1964 UI_FRAMES=${FR:-40}
run() { # bin mode sc ex
  local args=(); [ $4 = cpu12 ] && args=(--gpu off); [ $4 = cpu1 ] && args=(--gpu off --threads 1)
  local f=mx/$1-m$2-s$3-$4_r$round
  UI_MODE=$2 UI_SCEN=$3 perl -e 'alarm 240; exec @ARGV' ./$1 "${args[@]}" > $f.out 2> $f.err
  echo "$(date +%T) $f exit $? load $(sysctl -n vm.loadavg | awk '{print $2}')"
}
for round in 1 2 3; do
  for bin in dirtyp dirty; do
    for ex in cpu12 gpu; do
      [ $bin = dirty ] && [ $ex = gpu ] && continue
      run $bin 1 1 $ex; run $bin 1 3 $ex
      for sc in 0 1 2 3 4; do run $bin 2 $sc $ex; done
    done
  done
done
