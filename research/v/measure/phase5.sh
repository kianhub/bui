#!/bin/bash
cd "$(dirname "$0")"
export BEND_NO_TELEMETRY=1 UI_GLYPHS=2000 UI_PACE=0 UI_COLS=16 UI_ROWS=16 UI_W=1920 UI_H=1200 UI_FRAMES=10000 UI_BLIT=1
mkdir -p drift
echo "start $(date +%T) load $(sysctl -n vm.loadavg)"
UI_MODE=1 perl -e 'alarm 500; exec @ARGV' ./ui_blit > drift/bin-gpu.out 2> drift/bin-gpu.err; echo "bin-gpu done $(date +%T) exit $? $(grep prof drift/bin-gpu.err)"
UI_MODE=0 perl -e 'alarm 500; exec @ARGV' ./ui_blit --gpu off > drift/cull-cpu12.out 2> drift/cull-cpu12.err; echo "cull-cpu12 done $(date +%T) exit $? $(grep prof drift/cull-cpu12.err)"
UI_MODE=1 perl -e 'alarm 500; exec @ARGV' ./ui_win --gpu off > drift/win-bin-cpu12.out 2> drift/win-bin-cpu12.err; echo "win-bin-cpu12 done $(date +%T) exit $? $(grep prof drift/win-bin-cpu12.err)"
echo "end load $(sysctl -n vm.loadavg)"
python3 - <<'PY'
import glob, statistics as st, os
def q(xs,p): s=sorted(xs); return s[min(len(s)-1,int(len(s)*p))]
print("| run | frames | first 500: frame ms med / p90 | last 500: frame ms med / p90 | render med first/last | drop med first/last | rss_kb frame 5 | rss_kb end | errors |")
print("|---|---|---|---|---|---|---|---|---|")
for f in sorted(glob.glob('drift/*.out')):
    rows=[l.split() for l in open(f) if l.startswith('v ')]
    g=lambda rs,k: [int(r[r.index(k)+1]) for r in rs]
    a=rows[:500]; b=rows[-500:]
    err=open(f[:-4]+'.err').read(); errs=[l for l in err.splitlines() if not l.startswith(('bang','prof','blit_gpu_us'))]
    done=[l for l in open(f) if l.startswith('done')]
    print(f"| {os.path.basename(f)[:-4]} | {len(rows)} | {st.median(g(a,'frame_us'))/1000:.2f} / {q(g(a,'frame_us'),.9)/1000:.2f} | {st.median(g(b,'frame_us'))/1000:.2f} / {q(g(b,'frame_us'),.9)/1000:.2f} | {st.median(g(a,'render_us'))/1000:.2f} / {st.median(g(b,'render_us'))/1000:.2f} | {st.median(g(a,'drop_us'))/1000:.2f} / {st.median(g(b,'drop_us'))/1000:.2f} | {g(rows[5:6],'rss_kb')[0]} | {g(rows[-1:],'rss_kb')[0]} {done[0].strip() if done else ''} | {len(errs)} {errs[:2]} |")
    # rss trajectory every 1000 frames
    print("   rss_kb by 1000s:", [g(rows[i:i+1],'rss_kb')[0] for i in range(0,len(rows),1000)])
    print("   frame_us med by 1000s:", [round(st.median(g(rows[i:i+1000],'frame_us'))/1000,2) for i in range(0,len(rows),1000)])
PY
