import glob, re, os, statistics as st
from collections import defaultdict
R=defaultdict(list)
for f in sorted(glob.glob('mx/*.out')):
    tag=re.sub(r'_r\d\.out$','',os.path.basename(f))
    m=re.match(r'(\w+)-(\w+)-(\d+)', tag); kind,ex,rows=m.groups()
    lines=open(f).read().splitlines()
    el=[l for l in lines if l.startswith('elements')]
    V=[l.split() for l in lines if l.startswith('f ')]
    V=V[10:] if len(V)>20 else V[3:]
    if not V: print('empty', f, open(f[:-4]+'.err').read()[:300]); continue
    g=lambda k: [int(x[x.index(k)+1]) for x in V]
    R[(int(rows),kind,ex)].append({k: st.median(g(k)) for k in ('view_us','layout_us','paint_us','hit_us','core_us')} | {'n':len(V),'el':el[0].split()[1] if el else '?','ns':V[0][V[0].index('ns')+1],'nq':V[0][V[0].index('nq')+1],'cmin':min(g('core_us')),'cmax':max(g('core_us')),'p90':sorted(g('core_us'))[int(len(V)*.9)]})
print("| elements (rows) | glyphs / quads emitted | variant | runs x frames | view ms | layout (measure+wrap+place) ms | paint (scene+hitboxes) ms | hit+dispatch ms | core ms med (min-max of run medians) | p90 | all-frame range |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for k in sorted(R, key=lambda k:(k[0],k[1],k[2])):
    rows,kind,ex=k; rs=R[k]; m=lambda key: st.median([r[key] for r in rs])
    c=[r['core_us'] for r in rs]
    one = kind=='one' 
    f=lambda key: '-' if one else f"{m(key)/1000:.3f}"
    print(f"| {rs[0]['el']} ({rows}) | {rs[0]['ns']} / {rs[0]['nq']} | {kind} {ex} | {len(rs)}x{rs[0]['n']} | {f('view_us')} | {f('layout_us')} | {f('paint_us')} | {f('hit_us')} | {st.median(c)/1000:.3f} ({min(c)/1000:.3f}-{max(c)/1000:.3f}) | {m('p90')/1000:.3f} | {min(r['cmin'] for r in rs)/1000:.3f}-{max(r['cmax'] for r in rs)/1000:.3f} |")
