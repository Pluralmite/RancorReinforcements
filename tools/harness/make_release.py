#!/usr/bin/env python3
"""Make the release copy of the dev script: only K.RELEASE flips (everything dev-only is gated on it)."""
import sys, re
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding='utf-8').read()
n = len(re.findall(r'^K\.RELEASE = false$', s, flags=re.M))
if n != 1:
    sys.exit(f"expected exactly one 'K.RELEASE = false' line, found {n}")
s = re.sub(r'^K\.RELEASE = false$', 'K.RELEASE = true', s, flags=re.M)
open(dst, 'w', encoding='utf-8').write(s)
print("release copy written:", dst)
