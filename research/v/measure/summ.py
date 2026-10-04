import sys, glob, os, re, statistics as st
def med(xs): return st.median(xs) if xs else None
def frames(f, skip=3):
    rows=[l.split() for l in open(f) if l.startswith('v ')][skip:]
    g=lambda k: [int(r[r.index(k)+1]) for r in rows]
    return {k: g(k) for k in ('build_us','render_us','present_us','drop_us','frame_us','rss_kb')}
def bangs(f, skip=3):
    b=[l.split() for l in open(f) if l.startswith('bang ')]
    if not b: return {}
    mx=max(int(x[4]) for x in b)
    r=[float(x[8]) for x in b if int(x[4])==mx][skip:]; d=[float(x[8]) for x in b if int(x[4])!=mx][skip:]
    return {'render':r,'drop':d}
def f2(v): return "-" if v is None else f"{v/1000:.2f}"
if sys.argv[1]=='sweep':
    print("| exec | res | N | leaves | render ms | gpu-side render ms | drop ms | frame ms |"); print("|---|---|---|---|---|---|---|---|")
    for f in sorted(glob.glob('sweep/*.out'), key=lambda p:(p.split('_')[1], int(re.search(r'_n(\d+)',p).group(1)), p)):
        ex=os.path.basename(f).split('_')[0]; w=f.split('_')[1]; n=int(re.search(r'_n(\d+)',f).group(1))
        lv=re.search(r'leaves (\d+)', open(f).read()); fr=frames(f); bg=bangs(f[:-4]+'.err')
        print(f"| {ex} | {w} | {n} | {lv.group(1) if lv else '-'} | {f2(med(fr['render_us']))} | {f2(med(bg.get('render',[]))) if bg else '-'} | {f2(med(fr['drop_us']))} | {f2(med(fr['frame_us']))} |")
elif sys.argv[1]=='pace':
    for f in sorted(glob.glob('pace/ui_*.err')):
        b=bangs(f, 5); r=sorted(b['render']); d=sorted(b['drop'])
        p25=r[len(r)//4]; slow=[v for v in r if v>2*p25]
        fr=frames(f[:-4]+'.out',5)
        print(f"{os.path.basename(f)}: render n={len(r)} gpu_us p25={p25:.0f} med={r[len(r)//2]:.0f} p90={r[int(len(r)*0.9)]:.0f} max={r[-1]:.0f} slow(>2x p25)={len(slow)} ({100*len(slow)/len(r):.0f}%) | drop med={d[len(d)//2]:.0f} p90={d[int(len(d)*0.9)]:.0f} | wall render med={med(fr['render_us']):.0f} frame med={med(fr['frame_us']):.0f}")
    for f in sorted(glob.glob('pace/sdf*.err')):
        b=[l.split() for l in open(f) if l.startswith('bang ')][5:]
        g=sorted(float(x[8]) for x in b); p25=g[len(g)//4]; slow=[v for v in g if v>2*p25]
        out=[int(l.split()[1]) for l in open(f[:-4]+'.out') if l.startswith('frame_us')][5:]
        print(f"{os.path.basename(f)}: n={len(g)} gpu_us p25={p25:.0f} med={g[len(g)//2]:.0f} p90={g[int(len(g)*0.9)]:.0f} max={g[-1]:.0f} slow(>2x p25)={len(slow)} ({100*len(slow)/len(g):.0f}%) | wall frame_us med={st.median(out):.0f} min={min(out)} sum={set(l.split()[3] for l in open(f[:-4]+'.out') if l.startswith('frame_us'))}")
elif sys.argv[1]=='ovh':
    import collections
    for f in sorted(glob.glob('ovhd/*.err')):
        b=[l.split() for l in open(f) if l.startswith('bang ')]
        out=[l.split() for l in open(f[:-4]+'.out') if l.startswith('k ')]
        # bangs in order correspond to k 0..3 (40 each); k 4 has no bang
        by=collections.defaultdict(list); byw=collections.defaultdict(list)
        for i,x in enumerate(b): by[i//40].append(float(x[8])); 
        for r in out:
            k=int(r[1]); byw[k].append(int(r[3]))
        names={0:'single task',1:'1024 leaves',2:'16384 leaves',3:'65536 leaves',4:'no bang (CPU)'}
        for k in range(5):
            g=sorted(by[k])[3:] if k<4 else []; w=sorted(byw[k])[3:]
            print(f"{os.path.basename(f)} {names[k]}: gpu_us med={st.median(g):.0f} min={g[0]:.0f} max={g[-1]:.0f} | wall_us med={st.median(w):.0f} min={w[0]}" if g else f"{os.path.basename(f)} {names[k]}: wall_us med={st.median(w):.0f} min={w[0]} max={w[-1]}")
elif sys.argv[1]=='sdf':
    for f in sorted(glob.glob('sdfn/*.txt')):
        t=open(f).read()
        if 'bend' in f:
            out=[int(l.split()[1]) for l in t.splitlines() if l.startswith('frame_us')][3:]
            err=open(f.replace('.txt','.err')).read() if os.path.exists(f.replace('.txt','.err')) else ''
            g=sorted(float(l.split()[8]) for l in err.splitlines() if l.startswith('bang '))[3:]
            sums=set(l.split()[3] for l in t.splitlines() if l.startswith('frame_us'))
            print(f"{os.path.basename(f)}: wall_us med={st.median(out):.0f} min={min(out)} max={max(out)} gpu_us med={st.median(g) if g else '-'} sums={sums}")
        else:
            print(f"{os.path.basename(f)}: " + " | ".join(l for l in t.splitlines() if 'median' in l or 'check' in l.lower())[:400])
