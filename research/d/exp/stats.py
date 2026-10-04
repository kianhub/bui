import sys, re, statistics as st
from collections import defaultdict
d = defaultdict(list)
for line in open(sys.argv[1]):
    toks = line.split()
    # key: words that are not numbers before a numeric value
    prefix = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if i + 1 < len(toks) and re.fullmatch(r'\d+', toks[i+1]) and t.endswith('_us'):
            key = ' '.join(prefix + [t])
            d[key].append(int(toks[i+1]))
            i += 2
            continue
        if not re.fullmatch(r'\d+', t):
            prefix.append(t) if t not in ('sum',) else None
        i += 1
for k, v in d.items():
    s = sorted(v)
    w = s[1:] if len(s) > 5 else s  # drop first-frame outlier from median? keep all for min/max
    print(f"{k:40s} n={len(v)} first={v[0]} min={s[0]} median={st.median(v):.0f} median_excl_first={st.median(v[1:]):.0f} max={s[-1]}")
