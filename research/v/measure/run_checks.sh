#!/bin/bash
# correctness pass: UI_CHECK=1, 1 frame, every variant/res/N; prints the check lines
set +u
cd "$(dirname "$0")"
out=$1; ress=$2; ns=$3
mkdir -p "$out"
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_BLIT=1 UI_PACE=0 BLIT_CHECK=1 UI_CHECK=1 UI_FRAMES=1
for res in $ress; do
  w=${res%:*}; h=${res#*:}
  for n in $ns; do
    cols=$(python3 -c "import math;print(int(math.isqrt($n)))")
    for v in "cull 0 gpu" "bin 1 gpu" "cull 0 cpu12 --gpu off" "bin 1 cpu12 --gpu off" "cull 0 cpu1 --gpu off --threads 1" "bin 1 cpu1 --gpu off --threads 1"; do
      set -- $v; tag=$1; mode=$2; ex=$3; shift 3
      f="$out/check_${tag}_${ex}_${w}x${h}_n${n}"
      UI_MODE=$mode UI_COLS=$cols UI_ROWS=$cols UI_W=$w UI_H=$h perl -e 'alarm 300; exec @ARGV' ./ui_blit "$@" >"$f.out" 2>"$f.err"
      echo "$tag $ex ${w}x${h} n$n :: $(grep -E '^check|^blit_sum' "$f.out" | sed 's/check v [01] n [0-9]* w [0-9]* h [0-9]* //' | tr '\n' ' ') probes_ok $(grep -c 'ok True' "$f.out")/4 $(grep prof "$f.err")"
    done
  done
done
