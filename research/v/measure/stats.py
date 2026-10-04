#!/usr/bin/env python3
"""Aggregate run_matrix outputs.
usage: stats.py outdir [skip_frames=3]
Per (res, N, variant): per-run medians of render/present/drop/frame (us) over frames after skip,
then median and min..max of those run medians across runs. Also the GPU-side time of the render bang
(largest-arity bang per frame) from the .err bang log where present.
"""
import sys, re, glob, os, statistics as st
from collections import defaultdict
d = sys.argv[1]; skip = int(sys.argv[2]) if len(sys.argv) > 2 else 3
runs = defaultdict(list)   # key -> list of per-run dicts
for f in sorted(glob.glob(os.path.join(d, '*_r*.out'))):
    base = os.path.basename(f)[:-4]
    m = re.match(r'([\w-]+)_(\d+)x(\d+)_n(\d+)_r(\d+)', base)
    tag, w, h, n, r = m.groups()
    lines = [l for l in open(f) if l.startswith('v ')]
    if len(lines) <= skip: 
        print("short run", base, len(lines)); continue
    cols = defaultdict(list)
    for l in lines[skip:]:
        t = l.split()
        for k in ('build_us','render_us','present_us','drop_us','frame_us'):
            cols[k].append(int(t[t.index(k)+1]))
        cols['rss_kb'].append(int(t[t.index('rss_kb')+1]))
    rec = {k: st.median(v) for k, v in cols.items()}
    rec['frames'] = len(lines)
    # exec from err name? encoded in tag by driver: tag is cull/bin; exec in file name? we put exec in tag
    err = f[:-4] + '.err'
    gpu = []
    if os.path.exists(err):
        bangs = [l.split() for l in open(err) if l.startswith('bang ')]
        # render bang = the one whose arity is the max seen
        if bangs:
            ars = [int(b[4]) for b in bangs]
            mx = max(ars)
            gpu = [float(b[8]) for b in bangs if int(b[4]) == mx][skip:]
            drops = [float(b[8]) for b in bangs if int(b[4]) != mx][skip:]
            rec['gpu_render_us'] = st.median(gpu) if gpu else None
            rec['gpu_drop_us'] = st.median(drops) if drops else None
            rec['gpu_bangs'] = len(bangs)
        prof = [l for l in open(err) if l.startswith('prof ')]
        rec['prof'] = prof[-1].strip() if prof else ''
    runs[(int(w), int(h), int(n), tag)].append(rec)
def fmt(v): return f"{v/1000:.2f}" if v is not None else "-"
print("| variant | res | N | runs | render ms med (min-max) | present ms | drop ms | frame ms med (min-max) | gpu-side render ms | build ms |")
print("|---|---|---|---|---|---|---|---|---|---|")
for key in sorted(runs, key=lambda k: (k[0], k[2], k[3])):
    w, h, n, tag = key; rs = runs[key]
    def agg(k):
        vals = [r[k] for r in rs if r.get(k) is not None]
        if not vals: return "-"
        return f"{fmt(st.median(vals))} ({fmt(min(vals))}-{fmt(max(vals))})"
    def agg1(k):
        vals = [r[k] for r in rs if r.get(k) is not None]
        return fmt(st.median(vals)) if vals else "-"
    print(f"| {tag} | {w}x{h} | {n} | {len(rs)} | {agg('render_us')} | {agg1('present_us')} | {agg1('drop_us')} | {agg('frame_us')} | {agg1('gpu_render_us')} | {agg1('build_us')} |")
