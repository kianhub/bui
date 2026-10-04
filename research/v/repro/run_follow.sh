#!/bin/bash
# Follow-up probes after the matrix and idle runs:
#   busy:  P3 in the 2x window while another process keeps the GPU busy (headless P3 compute mode 1, N=1024, 1920x1200),
#          alternated with a plain window run, 2 rounds each -> does in-window GPU time fall when the GPU is kept clocked up?
#   rss:   core at 1250 rows for 2,000 frames with RSS sampled every 0.5 s
#   pace16: paced headless P3 at 16 ms between frames, 3 runs (pace trend: 0 / 3 / 8 / 16 ms)
cd "$(dirname "$0")"; mkdir -p win2 mx cmx logs
export BEND_NO_TELEMETRY=1
LOG=logs/run_follow.log
r() { # tag outdir timeout cmd...
  local tag=$1 dir=$2 to=$3; shift 3
  perl -e "alarm $to; exec @ARGV" "$@" > $dir/${tag}_r$round.out 2> $dir/${tag}_r$round.err
  echo "$(date +%T) $tag r$round exit $? load $(sysctl -n vm.loadavg | awk '{print $2}')" | tee -a $LOG
}
export UI_GLYPHS=2000 UI_COLS=16 UI_ROWS=16
for round in 1 2; do
  UI_W=3024 UI_H=1964 UI_FRAMES=120 P3_MODE=0 r p3w-plain win2 120 p3/p3win
  # background GPU load: compute-kernel P3, N=1024, about 16-35 ms of GPU per frame, 400 frames
  ( UI_COLS=32 UI_ROWS=32 UI_W=1920 UI_H=1200 UI_FRAMES=400 P3_MODE=1 perl -e 'alarm 90; exec @ARGV' p3/p3 --gpu off > win2/busybg_r$round.out 2> win2/busybg_r$round.err ) &
  bg=$!
  sleep 3
  UI_W=3024 UI_H=1964 UI_FRAMES=120 P3_MODE=0 r p3w-busy win2 120 p3/p3win
  wait $bg; echo "$(date +%T) busybg r$round done" | tee -a $LOG
done
round=rss
( UI_ROWS=1250 UI_FRAMES=2000 UI_ONE=1 UI_BANG=0 perl -e 'alarm 300; exec @ARGV' core/core --gpu off > cmx/one-cpu12-1250_rrss.out 2> cmx/one-cpu12-1250_rrss.err ) &
cp=$!
sleep 0.3
pid=$(pgrep -n -f 'core/core')
while kill -0 $pid 2>/dev/null; do echo "$(date +%s.%N) rss_kb $(ps -o rss= -p $pid | tr -d ' ')"; sleep 0.5; done > cmx/one-cpu12-1250_rrss.rss
wait $cp; echo "$(date +%T) core rss run done" | tee -a $LOG
for round in 1 2 3; do
  UI_W=3024 UI_H=1964 UI_FRAMES=100 UI_PACE=16 P3_MODE=0 r p3pace16-cpu12_3024x1964 mx 120 p3/p3pace --gpu off
done
echo "$(date +%T) follow done" | tee -a $LOG
