#!/bin/bash
# build.sh dir/name : emit C with the 565d7fd checkout, clang -O3 (ObjC/Metal, as main.ts does), --gpu-build
set -e
G=$(cd "$(dirname "$0")" && pwd)
export BEND_NO_TELEMETRY=1 TMPDIR=$G/tmp
d=$(dirname "$1"); n=$(basename "$1")
cd "$G/$d"
bun "${BENDTS:-$G/../../d/bend/bend2/main.ts}" $n.bend -o $n.c
clang -x objective-c -fobjc-arc -fmodules -std=c11 -O3 -DBEND_METAL=1 $n.c -lpthread -lm -o $n
if grep -q '^#define BANGS [1-9]' $n.c; then ./$n --gpu-build; fi
echo "built $d/$n: $(wc -l < $n.c) C lines, bangs $(grep -m1 '^#define BANGS' $n.c | awk '{print $3}')"
