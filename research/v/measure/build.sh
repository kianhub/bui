#!/bin/bash
# build.sh name [instr]  -> emits name.c, (patches), compiles, writes name.gpu
# prints: emit_s, clang_s, gpubuild_s
set -e
cd "$(dirname "$0")"
BEND=../../d/bend/bend2/main.ts
export BEND_NO_TELEMETRY=1
name=$1; instr=${2:-instr}
t0=$(python3 -c 'import time;print(time.time())')
bun $BEND $name.bend -o $name.c
t1=$(python3 -c 'import time;print(time.time())')
if [ "$instr" = "instr" ]; then python3 instr.py $name.c $name.i.c >/dev/null; src=$name.i.c; else src=$name.c; fi
clang -x objective-c -fobjc-arc -fmodules -std=c11 -O3 -DBEND_METAL=1 $src -lpthread -lm -o $name
t2=$(python3 -c 'import time;print(time.time())')
./$name --gpu-build
t3=$(python3 -c 'import time;print(time.time())')
python3 -c "print(f'build $name emit_s {$t1-$t0:.2f} clang_s {$t2-$t1:.2f} gpubuild_s {$t3-$t2:.2f} c_lines', end=' ')"; wc -l < $name.c; ls -la $name $name.gpu | awk '{print $5, $9}'
