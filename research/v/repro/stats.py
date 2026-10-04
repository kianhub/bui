#!/usr/bin/env python3
"""Summarise the repro logs. Usage: stats.py [mx|win|cmx|all]
Per tag (file name minus _rN): median of per-run medians, range of run medians,
p90 and max over all kept frames, and the share of frames over 12.5 ms.
Drops the first DROP frames of every run (the first frame compiles the GPU program)."""
import glob, re, os, sys, statistics as st
from collections import defaultdict

DROP = {'mx': 5, 'win': 5, 'cmx': 10}

def kv(line):
    t = line.split(); d = {}
    for i in range(len(t) - 1):
        try: d[t[i]] = float(t[i + 1])
        except ValueError: pass
    return d

def rows(path, prefix):
    return [kv(l) for l in open(path) if l.startswith(prefix)]

def med(xs): return st.median(xs) if xs else float('nan')
def p90(xs): return sorted(xs)[int(len(xs) * .9)] if xs else float('nan')
def corr(a, b):
    if len(a) < 3: return float('nan')
    ma, mb = st.mean(a), st.mean(b)
    num = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    den = (sum((x - ma) ** 2 for x in a) * sum((y - mb) ** 2 for y in b)) ** .5
    return num / den if den else float('nan')

def tag_of(f): return re.sub(r'_r(\d+|long)\.out$', '', os.path.basename(f))

def mx(d='mx'):
    print(f"\n## {d}: P3 headless (per run: {DROP['mx']} frames dropped)")
    print("| tag | runs x frames | gpu_us med (run range) | effect wall_us med | frame_us med (run range) | frame p90 | walk_us | encode_us | shared |")
    print("|---|---|---|---|---|---|---|---|---|")
    R = defaultdict(list)
    for f in sorted(glob.glob(f'{d}/*.out')):
        if 'long' in f: continue
        V = rows(f, 'v p3')[DROP['mx']:]
        P = rows(f[:-4] + '.err', 'p3 mode')[DROP['mx']:]
        if not V or not P: print('empty', f); continue
        R[tag_of(f)].append(dict(n=len(V), frame=[v['frame_us'] for v in V], gpu=[p['gpu_us'] for p in P],
            wall=[p['wall_us'] for p in P], walk=[p['walk_us'] for p in P], enc=[p['encode_us'] for p in P], shared=int(P[0]['shared'])))
    for k in sorted(R):
        rs = R[k]; m = lambda key: [med(r[key]) for r in rs]
        allf = [x for r in rs for x in r['frame']]
        print(f"| {k} | {len(rs)}x{rs[0]['n']} | {med(m('gpu')):.0f} ({min(m('gpu')):.0f}-{max(m('gpu')):.0f}) | {med(m('wall')):.0f} | {med(m('frame')):.0f} ({min(m('frame')):.0f}-{max(m('frame')):.0f}) | {p90(allf):.0f} | {med(m('walk')):.1f} | {med(m('enc')):.1f} | {rs[0]['shared']} |")

def win(d='win'):
    print(f"\n## {d}: real 2x window, 3024x1964 drawable (per run: {DROP['win']} frames dropped)")
    print("| tag | runs x frames | frame_us med (run range) | p90 | max | frames > 12.5 ms | frames > 25 ms | frames > 9 ms | render_us med | present_us med | gpu_us med (run range) | gpu p90 | gpu min | corr(encode,gpu) | encode+gpu med |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    R = defaultdict(list)
    for f in sorted(glob.glob(f'{d}/*.out')):
        V = rows(f, 'v ')[DROP['win']:]
        if not V: print('empty', f); continue
        if 'present_us' not in V[0]: continue  # not a window log (e.g. a background-load run)
        rec = dict(n=len(V), frame=[v['frame_us'] for v in V], present=[v['present_us'] for v in V],
                   render=[v['render_us'] for v in V if 'render_us' in v])
        P = rows(f[:-4] + '.err', 'p3 mode')[DROP['win']:]
        if P:
            rec['gpu'] = [p['gpu_us'] for p in P]; rec['enc'] = [p['encode_us'] for p in P]
        R[tag_of(f)].append(rec)
    for k in sorted(R):
        rs = R[k]; m = lambda key: [med(r[key]) for r in rs if r.get(key)]
        allf = [x for r in rs for x in r['frame']]
        over = lambda t: sum(1 for x in allf if x > t)
        g = ''
        if rs[0].get('gpu'):
            allg = [x for r in rs for x in r['gpu']]
            cs = [corr(r['enc'], r['gpu']) for r in rs]
            sums = [med([a + b for a, b in zip(r['enc'], r['gpu'])]) for r in rs]
            g = f"{med(m('gpu')):.0f} ({min(m('gpu')):.0f}-{max(m('gpu')):.0f}) | {p90(allg):.0f} | {min(allg):.0f} | {min(cs):.2f}..{max(cs):.2f} | {med(sums):.0f}"
        else:
            g = "- | - | - | - | -"
        ren = f"{med(m('render')):.0f}" if m('render') else '-'
        print(f"| {k} | {len(rs)}x{rs[0]['n']} | {med(m('frame')):.0f} ({min(m('frame')):.0f}-{max(m('frame')):.0f}) | {p90(allf):.0f} | {max(allf):.0f} | {over(12500)}/{len(allf)} ({100*over(12500)/len(allf):.1f}%) | {over(25000)}/{len(allf)} | {over(9000)}/{len(allf)} | {ren} | {med(m('present')):.0f} | {g} |")

def cmx(d='cmx'):
    print(f"\n## {d}: framework core, one expression, --gpu off (per run: {DROP['cmx']} frames dropped)")
    print("| tag | elements | nq / ns | runs x frames | core_us med (run range) | p90 | first-10 med | last-10 med | last/first |")
    print("|---|---|---|---|---|---|---|---|---|")
    R = defaultdict(list)
    for f in sorted(glob.glob(f'{d}/*.out')):
        lines = open(f).read().splitlines()
        el = [l for l in lines if l.startswith('elements')]
        V = [kv(l) for l in lines if l.startswith('f ')]
        if len(V) < 20: print('short', f, len(V)); continue
        K = V[DROP['cmx']:]
        c = [v['core_us'] for v in K]
        rec = dict(n=len(K), core=c, el=el[0].split()[1] if el else '?', nq=int(V[0]['nq']), ns=int(V[0]['ns']),
                   first=med(c[:10]), last=med(c[-10:]), long='long' in f)
        R[tag_of(f) + (' (2000 frames)' if rec['long'] else '')].append(rec)
    for k in sorted(R, key=lambda k: (int(re.search(r'-(\d+)', k).group(1)), k)):
        rs = R[k]; m = lambda key: [med(r[key]) if isinstance(r[key], list) else r[key] for r in rs]
        allc = [x for r in rs for x in r['core']]
        print(f"| {k} | {rs[0]['el']} | {rs[0]['nq']} / {rs[0]['ns']} | {len(rs)}x{rs[0]['n']} | {med(m('core')):.0f} ({min(m('core')):.0f}-{max(m('core')):.0f}) | {p90(allc):.0f} | {med(m('first')):.0f} | {med(m('last')):.0f} | {med(m('last'))/med(m('first')):.2f} |")
    for f in sorted(glob.glob(f'{d}/*_rlong.out')):
        V = [kv(l) for l in open(f) if l.startswith('f ')]
        c = [v['core_us'] for v in V]
        blocks = [med(c[i:i + 100]) for i in range(0, len(c), 100)]
        print(f"\n{os.path.basename(f)}: per-100-frame medians of core_us ({len(c)} frames): " + ' '.join(f"{b:.0f}" for b in blocks))

if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if what in ('mx', 'all'): mx()
    if what in ('win', 'all'): win()
    if what in ('cmx', 'all'): cmx()
