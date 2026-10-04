import sys, statistics as st
def q(xs,p): s=sorted(xs); return s[min(len(s)-1,int(len(s)*p))]
for f in sys.argv[1:]:
    rows=[l.split() for l in open(f) if l.startswith('v ')]
    g=lambda rs,k: [int(r[r.index(k)+1]) for r in rs if k in r]
    print(f"== {f}: {len(rows)} frames; done line: {[l.strip() for l in open(f) if l.startswith('done')]}")
    a=rows[5:1005]; b=rows[-1000:]
    for k in ('map_us','build_us','render_us','present_us','drop_us','frame_us'):
        if not g(a,k): continue
        A=g(a,k); B=g(b,k)
        print(f"  {k:11s} first1000 med {st.median(A)/1000:.3f} p90 {q(A,.9)/1000:.3f} min {min(A)/1000:.3f} max {max(A)/1000:.2f} | last1000 med {st.median(B)/1000:.3f} p90 {q(B,.9)/1000:.3f} min {min(B)/1000:.3f} max {max(B)/1000:.2f} | ratio {st.median(B)/max(1,st.median(A)):.2f}")
    R=g(rows,'rss_kb')
    print(f"  rss_kb: frame5 {R[5]} frame1000 {R[1000]} max-first1000 {max(R[:1000])} | last1000 min {min(R[-1000:])} max {max(R[-1000:])} end {R[-1]}")
    print("  frame ms median per 2000-frame block:", [round(st.median(g(rows[i:i+2000],'frame_us'))/1000,2) for i in range(0,len(rows),2000)])
    print("  render ms median per 2000-frame block:", [round(st.median(g(rows[i:i+2000],'render_us'))/1000,2) for i in range(0,len(rows),2000)])
    if g(rows,'map_us'):
        print("  map ms median per 2000-frame block:", [round(st.median(g(rows[i:i+2000],'map_us'))/1000,3) for i in range(0,len(rows),2000)])
        print("  build(text+sprites) ms median per 2000-frame block:", [round(st.median(g(rows[i:i+2000],'build_us'))/1000,3) for i in range(0,len(rows),2000)])
    print("  rss_kb per 2000 frames:", [R[i] for i in range(0,len(R),2000)])
    ch=g(rows,'chars'); 
    if ch: print("  chars per frame: min", min(ch[1:]), "max", max(ch))
