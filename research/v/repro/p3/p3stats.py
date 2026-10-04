import glob, re, os, statistics as st
from collections import defaultdict
R=defaultdict(list)
for f in sorted(glob.glob('mx/*.err')):
    m=re.match(r'm(\d)-(\w+)_(\d+)x(\d+)_n(\d+)_r(\d)', os.path.basename(f)); mode,ex,w,h,n,r=m.groups()
    P=[l.split() for l in open(f) if l.startswith('p3 ')][3:]
    V=[l.split() for l in open(f[:-4]+'.out') if l.startswith('v p3')][3:]
    if not P: print('empty',f); continue
    g=lambda rs,k: [float(x[x.index(k)+1]) for x in rs]
    R[(int(w),int(n),int(mode),ex)].append(dict(gpu=st.median(g(P,'gpu_us')),wall=st.median(g(P,'wall_us')),walk=st.median(g(P,'walk_us')),enc=st.median(g(P,'encode_us')),
      build=st.median(g(V,'build_us')),frame=st.median(g(V,'frame_us')),drop=st.median(g(V,'drop_us')),nf=len(V),shared=P[0][P[0].index('shared')+1]))
print("| mode | exec | res | N | runs x frames | walk us | encode us | GPU-side ms med (min-max of run medians) | effect wall ms | build ms | drop ms | frame ms med (min-max) | shared heap |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for k in sorted(R):
    w,n,mode,ex=k; rs=R[k]
    a=lambda key: (st.median([r[key] for r in rs]), min(r[key] for r in rs), max(r[key] for r in rs))
    gp=a('gpu'); fr=a('frame')
    print(f"| {mode} | {ex} | {w} | {n} | {len(rs)}x{rs[0]['nf']} | {a('walk')[0]:.1f} | {a('enc')[0]:.1f} | {gp[0]/1000:.3f} ({gp[1]/1000:.3f}-{gp[2]/1000:.3f}) | {a('wall')[0]/1000:.3f} | {a('build')[0]/1000:.3f} | {a('drop')[0]/1000:.3f} | {fr[0]/1000:.3f} ({fr[1]/1000:.3f}-{fr[2]/1000:.3f}) | {rs[0]['shared']} |")
