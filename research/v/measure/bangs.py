#!/usr/bin/env python3
"""bangs.py file.err [skip=3] : per-bang stats from BANG_LOG. Render bang = max arity fid."""
import sys, statistics as st
f = sys.argv[1]; skip = int(sys.argv[2]) if len(sys.argv) > 2 else 3
b = [l.split() for l in open(f) if l.startswith('bang ')]
if not b: print(f, "no bangs"); sys.exit()
ar = [int(x[4]) for x in b]; mx = max(ar)
def col(name, rows):
    i = rows[0].index(name) + 1
    return [float(r[i]) for r in rows]
for label, rows in (("render", [x for x in b if int(x[4]) == mx][skip:]), ("drop", [x for x in b if int(x[4]) != mx][skip:])):
    if not rows: continue
    g = col('gpu_us', rows); w = col('wall_us', rows); lag = col('lag_us', rows); p = col('passes', rows)
    gs = sorted(g); med = st.median(g)
    slow = sum(1 for v in g if v > 2 * gs[len(gs)//4])  # > 2x the p25
    print(f"{f.split('/')[-1]} {label}: n={len(g)} passes={sorted(set(int(x) for x in p))} gpu_us min={gs[0]:.0f} p25={gs[len(gs)//4]:.0f} med={med:.0f} p75={gs[3*len(gs)//4]:.0f} max={gs[-1]:.0f} slow(>2x p25)={slow} lag_us med={st.median(lag):.0f} max={max(lag):.0f} wall-gpu med={st.median([a-b for a,b in zip(w,g)]):.0f}")
