#!/usr/bin/env python3
"""Reorder top-level blocks of a .bend file so every def comes after the defs
it references (Bend 2 rejects forward references). Stable otherwise."""
import sys, re
src = open(sys.argv[1]).read()
lines = src.split('\n')
blocks = []; cur = []
for ln in lines:
    if re.match(r'^(def|type|law|import) ', ln) or (re.match(r'^#', ln) and cur and not cur[-1].startswith('#') and cur[-1].strip()=='' ):
        if cur: blocks.append(cur)
        cur = [ln]
    else:
        cur.append(ln)
if cur: blocks.append(cur)
def name(b):
    for ln in b:
        m = re.match(r'^(def|type|law) ([\w.]+)', ln)
        if m: return m.group(2)
    return None
names = [name(b) for b in blocks]
owner = {}
for i, (b, n) in enumerate(zip(blocks, names)):
    if n: owner[n] = i
    if b and b[0].startswith('type '):
        for ln in b[1:]:
            m = re.match(r'^  ([A-Z][\w.]*)\{', ln)
            if m: owner.setdefault(m.group(1), i)
deps = []
for i, (b, n) in enumerate(zip(blocks, names)):
    body = re.sub(r'[+-]?[A-Za-z_][\w.]*\s*:(?!=)', ' ', '\n'.join(l for l in b if not l.lstrip().startswith('#')))
    toks = set(re.findall(r'([A-Za-z_][\w.]*)\s*!?[({]', body)) | set(re.findall(r'\b([A-Z][\w.]*)', body))
    deps.append(set(owner[t] for t in toks if t in owner and owner[t] != i))
out = []; done = set(); placed = [False]*len(blocks)
def place(i, stack=()):
    if placed[i]: return
    if i in stack: return
    for d in sorted(deps[i]):
        place(d, stack + (i,))
    if not placed[i]:
        placed[i] = True; out.append(blocks[i])
for i in range(len(blocks)): place(i)
open(sys.argv[2] if len(sys.argv) > 2 else sys.argv[1], 'w').write('\n'.join('\n'.join(b) for b in out))
