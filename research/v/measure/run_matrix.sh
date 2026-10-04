#!/bin/bash
# Alternating matrix: for each resolution and N, rounds of
#   cull-gpu, bin-gpu, cull-cpu12, bin-cpu12, cull-cpu1, bin-cpu1
# usage: run_matrix.sh outdir rounds frames "W:H ..." "N ..."
set +u
cd "$(dirname "$0")"
out=$1; rounds=$2; frames=$3; ress=$4; ns=$5
mkdir -p "$out"
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_BLIT=1 UI_PACE=0 BANG_LOG=1
run() { # tag mode exec
  local tag=$1 mode=$2 ex=$3 w=$4 h=$5 n=$6 round=$7
  local cols; cols=$(python3 -c "import math;print(int(math.isqrt($n)))")
  local args=()
  case $ex in gpu) args=();; cpu12) args=(--gpu off);; cpu1) args=(--gpu off --threads 1);; esac
  local f="$out/${tag}-${ex}_${w}x${h}_n${n}_r${round}"
  UI_MODE=$mode UI_COLS=$cols UI_ROWS=$cols UI_W=$w UI_H=$h UI_FRAMES=$frames \
    perl -e 'alarm 300; exec @ARGV' ./ui_blit "${args[@]}" >"$f.out" 2>"$f.err"
  echo "$(date +%T) $f exit $? $(grep -c '^v ' "$f.out") frames gpu_util $(tail -1 gpuutil.log | awk '{print $3}')"
}
for res in $ress; do
  w=${res%:*}; h=${res#*:}
  for n in $ns; do
    for round in $(seq 1 "$rounds"); do
      run cull 0 gpu   $w $h $n $round
      run bin  1 gpu   $w $h $n $round
      run cull 0 cpu12 $w $h $n $round
      run bin  1 cpu12 $w $h $n $round
      run cull 0 cpu1  $w $h $n $round
      run bin  1 cpu1  $w $h $n $round
    done
  done
done
