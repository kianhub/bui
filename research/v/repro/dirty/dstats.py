import glob, re, os, statistics as st, sys
from collections import defaultdict
R=defaultdict(list)
d=sys.argv[1] if len(sys.argv)>1 else 'mx'
for f in sorted(glob.glob(d+'/*.out')):
    m=re.match(r'(\w+)-m(\d)-s(\d)-(\w+)_r(\d)', os.path.basename(f)); b,mode,sc,ex,r=m.groups()
    V=[l.split() for l in open(f) if l.startswith('v ')][3:]
    if not V: print('empty', f, open(f[:-4]+'.err').read()[:200]); continue
    g=lambda k: [int(x[x.index(k)+1]) for x in V]
    R[(b,int(mode),int(sc),ex)].append({k: st.median(g(k)) for k in ('build_us','render_us','present_us','drop_us','frame_us')} | {'n':len(V),'dirty':V[0][V[0].index('dirty_px')+1], 'fmin':min(g('frame_us')),'fmax':max(g('frame_us'))})
names={0:'static',1:'hover card',2:'caret',3:'text column',4:'all moves'}
print("| glyphs | exec | mode | scenario | dirty px | runs x frames | render ms | present ms | drop ms | frame ms med (min-max of run medians) | frame min-max over all frames |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for k in sorted(R):
    b,mode,sc,ex=k; rs=R[k]
    med=lambda key: st.median([r[key] for r in rs])
    fr=[r['frame_us'] for r in rs]
    print(f"| {'tree (shared refs)' if b=='dirty' else 'hash (procedural)'} | {ex} | {'full' if mode==1 else 'incremental'} | {names[sc]} | {rs[0]['dirty']} | {len(rs)}x{rs[0]['n']} | {med('render_us')/1000:.2f} | {med('present_us')/1000:.2f} | {med('drop_us')/1000:.2f} | {st.median(fr)/1000:.2f} ({min(fr)/1000:.2f}-{max(fr)/1000:.2f}) | {min(r['fmin'] for r in rs)/1000:.2f}-{max(r['fmax'] for r in rs)/1000:.2f} |")
