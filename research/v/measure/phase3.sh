#!/bin/bash
cd "$(dirname "$0")"
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_BLIT=1 UI_PACE=0 BANG_LOG=1 UI_MODE=1 UI_FRAMES=12
mkdir -p front prof
echo "=== frontier size per bang (gpu_us/f): LANES=$(grep -m1 '#define LANES' ui_blit.i.c | awk '{print $3}') CUBE_T=$(grep -m1 '#define CUBE_T' ui_blit.i.c | awk '{print $3}')"
for cfg in "1920 1200 2" "1920 1200 8" "1920 1200 32" "3024 1964 8" "3024 1964 32"; do
  set -- $cfg
  UI_W=$1 UI_H=$2 UI_COLS=$3 UI_ROWS=$3 ./ui_blit > front/${1}_c$3.out 2> front/${1}_c$3.err
  echo "${1}x${2} N=$(( $3 * $3 )) render: $(grep '^bang' front/${1}_c$3.err | awk '$5==5{printf "%d/f%d ", $9, $NF}' | cut -c1-230)"
  echo "   drop: $(grep '^bang' front/${1}_c$3.err | awk '$5==1{printf "%d/f%d ", $9, $NF}' | cut -c1-150)"
done
echo "=== sdf cpu1 (C15)"
for r in 1 2 3; do ./sdf --gpu off --threads 1 > sdfn/cpu1_r$r.txt 2>&1
python3 -c "
import statistics as st
o=[int(l.split()[1]) for l in open('sdfn/cpu1_r$r.txt') if l.startswith('frame_us')][3:]
print('sdf cpu1 r$r wall_us med', st.median(o), 'min', min(o), 'max', max(o), 'first sum', [l.split()[3] for l in open('sdfn/cpu1_r$r.txt') if l.startswith('frame_us')][0])"; done
echo "=== slash boss probe x3 (SLASH_PROBE=1200, mix to /dev/null)"
for r in 1 2 3; do SLASH_PROBE=1200 SLASH_WAV=/dev/null perl -e 'alarm 120; exec @ARGV' ./slash 2>&1 | tail -1; done
echo "=== sample profiles (not timing-reported): cull-cpu12 and bin-gpu at 1920 N=256, 400 frames"
UI_MODE=0 UI_COLS=16 UI_ROWS=16 UI_W=1920 UI_H=1200 UI_FRAMES=400 ./ui_blit --gpu off > prof/cpu12.out 2> prof/cpu12.err &
pid=$!; sleep 1.0; sample $pid 2 -mayDie -file prof/cpu12.sample.txt > /dev/null 2>&1; wait $pid
UI_MODE=1 UI_COLS=16 UI_ROWS=16 UI_W=1920 UI_H=1200 UI_FRAMES=400 ./ui_blit > prof/gpu.out 2> prof/gpu.err &
pid=$!; sleep 1.0; sample $pid 2 -mayDie -file prof/gpu.sample.txt > /dev/null 2>&1; wait $pid
for f in prof/cpu12.sample.txt prof/gpu.sample.txt; do echo "--- $f"; grep -E "^Call graph|Total number in stack|Thread_|^ *[0-9]+ " $f | head -0; python3 - "$f" <<'PY'
import sys,re
t=open(sys.argv[1]).read()
# thread summary: lines like "    Thread_12345   DispatchQueue_1: com.apple.main-thread  (serial)" followed by sample counts; use the "Sort by top of stack" section
i=t.find('Sort by top of stack')
sec=t[i:i+3000] if i>=0 else ''
print(sec[:2200])
PY
done
