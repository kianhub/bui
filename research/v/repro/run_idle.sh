#!/bin/bash
# Item 4, idle cost in a real 2x window with an unchanged Scene:
#   present:        P3.present every vsync for 3,600 frames (about 30 s)
#   wait-bounded:   P3.wait bounded by the runtime's soonest timer / runnable task; ticker every 250 ms; 120 wakes
#   wait-unbounded: P3.wait for up to 1,000 ms regardless of timers (control); 30 wakes
# Samples once a second: GPU "Device Utilization %" (ioreg IOAccelerator), top CPU% of the test process and WindowServer.
# A 15 s baseline with nothing of ours running comes first. /usr/bin/time -l gives the process's total user+sys time.
cd "$(dirname "$0")"; mkdir -p idle
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16 UI_W=3024 UI_H=1964
WS=$(pgrep -x WindowServer)
gpu() { ioreg -r -c IOAccelerator -d 1 | grep -o '"Device Utilization %"=[0-9]*' | head -1 | cut -d= -f2; }
sampler() { local tag=$1 n=$2; for i in $(seq $n); do echo "$(date +%T) gpu $(gpu)"; sleep 1; done > idle/$tag.gpu; }
run() { # tag secs cmd...
  local tag=$1 secs=$2; shift 2
  echo "$(date +%T) start $tag load $(sysctl -n vm.loadavg | awk '{print $2}')" | tee -a idle/log
  ( /usr/bin/time -l perl -e "alarm $((secs+40)); exec @ARGV" "$@" > idle/$tag.out 2> idle/$tag.err ) &
  local sh=$!
  sleep 2
  local pid=$(pgrep -n -f 'p3/p3idle')
  top -l $secs -s 1 -pid $pid -pid $WS -stats pid,cpu,command > idle/$tag.top 2>&1 &
  local tp=$!
  sampler $tag $secs &
  local sp=$!
  wait $sh; wait $tp; wait $sp
  echo "$(date +%T) end $tag" | tee -a idle/log
}
echo "$(date +%T) baseline 15 s" | tee -a idle/log
top -l 15 -s 1 -pid $WS -stats pid,cpu,command > idle/baseline.top 2>&1 &
sampler baseline 15; wait
IDLE_MODE=0 UI_FRAMES=3600 run present 30 p3/p3idle
IDLE_MODE=1 IDLE_BOUNDED=1 IDLE_WAKES=120 IDLE_TICKS=120 IDLE_TICK_MS=250 run wait-bounded 30 p3/p3idle
IDLE_MODE=1 IDLE_BOUNDED=0 IDLE_WAKES=30 IDLE_TICKS=40 IDLE_TICK_MS=250 run wait-unbounded 33 p3/p3idle
echo "$(date +%T) done" | tee -a idle/log
