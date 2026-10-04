import glob, re, os, statistics as st
from collections import defaultdict
R=defaultdict(list)
for f in sorted(glob.glob('win/*.out')):
    tag=re.sub(r'_r\d\.out$','',os.path.basename(f))
    V=[l.split() for l in open(f) if l.startswith('v ')][5:]
    if not V: print('empty',f); continue
    g=lambda k: [int(x[x.index(k)+1]) for x in V if k in x]
    fr=g('frame_us')
    rec={'frame':st.median(fr),'p90':sorted(fr)[int(len(fr)*.9)],'max':max(fr),'n':len(fr),
         'over83':sum(1 for x in fr if x>12500)/len(fr),'over167':sum(1 for x in fr if x>25000)/len(fr),
         'render':st.median(g('render_us')) if g('render_us') else None,'present':st.median(g('present_us'))}
    if tag=='p3w':
        P=[l.split() for l in open(f[:-4]+'.err') if l.startswith('p3 ')][5:]
        rec['gpu']=st.median([float(x[x.index('gpu_us')+1]) for x in P])
        rec['render']=None
    R[tag].append(rec)
print("| variant (3024x1964 drawable, real window) | runs x frames | render ms | Window.frame / present ms | frame ms med (min-max of run medians) | p90 | worst | frames > 12.5 ms (missed a 120 Hz vsync) | frames > 25 ms (missed 60 Hz) |")
print("|---|---|---|---|---|---|---|---|---|")
for k in sorted(R):
    rs=R[k]; m=lambda key: st.median([r[key] for r in rs])
    fr=[r['frame'] for r in rs]
    ren = f"{m('render')/1000:.2f}" if rs[0]['render'] is not None else (f"(GPU {m('gpu')/1000:.2f})" if 'gpu' in rs[0] else '-')
    print(f"| {k} | {len(rs)}x{rs[0]['n']} | {ren} | {m('present')/1000:.2f} | {st.median(fr)/1000:.2f} ({min(fr)/1000:.2f}-{max(fr)/1000:.2f}) | {m('p90')/1000:.2f} | {max(r['max'] for r in rs)/1000:.1f} | {st.mean([r['over83'] for r in rs])*100:.0f}% | {st.mean([r['over167'] for r in rs])*100:.0f}% |")
