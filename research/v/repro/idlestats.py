import re, statistics as st, glob
def top(f, name):
    xs=[]; first=True
    for l in open(f):
        m=re.match(r'^\d+\s+([\d.]+)\s+(\S+)', l)
        if m and m.group(2).startswith(name): xs.append(float(m.group(1)))
    return xs[1:] if len(xs)>1 else xs   # top's first sample is always 0
def gpu(f): return [int(l.split()[2]) for l in open(f) if len(l.split())>2 and l.split()[2].isdigit()]
def timel(f):
    d={}
    for l in open(f):
        m=re.match(r'\s*([\d.]+)\s+(real|user|sys)\s*$', l)
        if m: d[m.group(2)]=float(m.group(1))
    return d
def q(xs): return f"med {st.median(xs):.1f} mean {st.mean(xs):.1f} min {min(xs):.0f} max {max(xs):.0f} (n {len(xs)})" if xs else "n/a"
print("baseline: WindowServer CPU%", q(top('idle/baseline.top','WindowServer')), "| GPU util%", q(gpu('idle/baseline.gpu')))
for tag in ['present','wait-bounded','wait-unbounded']:
    t=timel(f'idle/{tag}.err')
    print(f"\n== {tag}")
    print("  p3idle CPU% (top, 1 s samples):", q(top(f'idle/{tag}.top','p3idle')))
    print("  WindowServer CPU%:", q(top(f'idle/{tag}.top','WindowServer')))
    print("  GPU util%:", q(gpu(f'idle/{tag}.gpu')))
    if t: print(f"  time -l: real {t.get('real')} s user {t.get('user')} s sys {t.get('sys')} s -> avg CPU {(t.get('user',0)+t.get('sys',0))/t['real']*100:.1f}%")
    out=open(f'idle/{tag}.out').read().splitlines()
    nfr=sum(1 for l in open(f'idle/{tag}.err') if l.startswith('p3 mode'))
    print(f"  frames presented: {nfr}")
    ticks=[int(l.split()[2]) for l in out if l.startswith('tick us')]
    if ticks:
        iv=[(b-a)/1000 for a,b in zip(ticks,ticks[1:])]
        lat=[int(l.split()[6]) for l in out if l.startswith('recv ')]
        waits=[float(l.split()[l.split().index('waited_ms')+1]) for l in open(f'idle/{tag}.err') if l.startswith('wait ')]
        wakes=[l for l in out if l.startswith('wake')]
        # ticks that happened while the main loop was still running (before 'done')
        di=out.index('done') if 'done' in out else len(out)
        tin=sum(1 for l in out[:di] if l.startswith('tick us'))
        print(f"  ticks: {len(ticks)} ({tin} before main loop ended); interval ms med {st.median(iv):.1f} min {min(iv):.1f} max {max(iv):.1f} (target 250)")
        print(f"  recv latency us: med {st.median(lat):.0f} p90 {sorted(lat)[int(.9*len(lat))]} max {max(lat)} (n {len(lat)})")
        print(f"  waits: {len(waits)}; waited_ms med {st.median(waits):.1f} min {min(waits):.1f} max {max(waits):.1f}; wakes {len(wakes)}")
