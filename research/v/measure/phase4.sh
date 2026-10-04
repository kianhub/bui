#!/bin/bash
cd "$(dirname "$0")"
export BEND_NO_TELEMETRY=1 BANG_LOG=1
mkdir -p app win
echo "=== App.run view bang: app_bigg (grad! in view) vs app_big (no bang), 120 frames, 1920x1200 window, x3 alternations"
for r in 1 2 3; do
  perl -e 'alarm 60; exec @ARGV' ./app_bigg > app/bigg_r$r.out 2> app/bigg_r$r.err; echo "bigg gpu r$r: $(cat app/bigg_r$r.out | tr '\n' ' ') | bangs: $(grep -c '^bang' app/bigg_r$r.err) $(grep prof app/bigg_r$r.err) | render-bang gpu_us med $(grep '^bang' app/bigg_r$r.err | awk '$5==4{print $9}' | sort -n | awk '{a[NR]=$1} END{print a[int(NR/2)]}') drop-bang med $(grep '^bang' app/bigg_r$r.err | awk '$5==1{print $9}' | sort -n | awk '{a[NR]=$1} END{print a[int(NR/2)]}')"
  perl -e 'alarm 60; exec @ARGV' ./app_big > app/big_r$r.out 2> app/big_r$r.err; echo "big  gpu r$r: $(cat app/big_r$r.out | tr '\n' ' ') | bangs: $(grep -c '^bang' app/big_r$r.err) $(grep prof app/big_r$r.err) | drop-bang med $(grep '^bang' app/big_r$r.err | awk '{print $9}' | sort -n | awk '{a[NR]=$1} END{print a[int(NR/2)]}')"
  perl -e 'alarm 60; exec @ARGV' ./app_bigg --gpu off > app/biggoff_r$r.out 2> app/biggoff_r$r.err; echo "bigg --gpu off r$r: $(cat app/biggoff_r$r.out | tr '\n' ' ') | $(grep prof app/biggoff_r$r.err)"
  perl -e 'alarm 60; exec @ARGV' ./app_big --gpu off > app/bigoff_r$r.out 2> app/bigoff_r$r.err; echo "big  --gpu off r$r: $(cat app/bigoff_r$r.out | tr '\n' ' ') | $(grep prof app/bigoff_r$r.err)"
done
echo "=== arity of fids in app_bigg bang log (ar 4 = grad, ar 1 = Image.free?)"; grep '^bang' app/bigg_r1.err | awk '{print $3, $5}' | sort | uniq -c
echo "=== real Window.frame present: ui_win 1920x1200 N=256, 120 frames, x3 alternations"
export UI_GLYPHS=2000 UI_PACE=0 UI_COLS=16 UI_ROWS=16 UI_W=1920 UI_H=1200 UI_FRAMES=120
for r in 1 2 3; do
  UI_MODE=1 perl -e 'alarm 120; exec @ARGV' ./ui_win > win/bin-gpu_r$r.out 2> win/bin-gpu_r$r.err
  UI_MODE=1 perl -e 'alarm 120; exec @ARGV' ./ui_win --gpu off > win/bin-cpu12_r$r.out 2> win/bin-cpu12_r$r.err
  UI_MODE=0 perl -e 'alarm 120; exec @ARGV' ./ui_win --gpu off > win/cull-cpu12_r$r.out 2> win/cull-cpu12_r$r.err
done
python3 - <<'PY'
import glob, statistics as st, os
print("| variant | run | frames | render ms | present (Window.frame) ms | drop ms | frame ms | min frame | prof |")
print("|---|---|---|---|---|---|---|---|---|")
for f in sorted(glob.glob('win/*.out')):
    rows=[l.split() for l in open(f) if l.startswith('v ')][5:]
    if not rows: print(f, "no frames", open(f[:-4]+'.err').read()[:300]); continue
    g=lambda k: [int(r[r.index(k)+1]) for r in rows]
    prof=[l.strip() for l in open(f[:-4]+'.err') if l.startswith('prof')]
    print(f"| {os.path.basename(f)[:-4]} | | {len(rows)} | {st.median(g('render_us'))/1000:.2f} | {st.median(g('present_us'))/1000:.2f} | {st.median(g('drop_us'))/1000:.2f} | {st.median(g('frame_us'))/1000:.2f} | {min(g('frame_us'))/1000:.2f} | {prof[-1] if prof else ''} |")
PY
pgrep -fl "ui_win|app_big" || echo "no leftover windows"
