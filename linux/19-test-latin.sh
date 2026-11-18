#!/usr/bin/env bash
# Comprueba que LATIN de aafix.c y de validate-table.py son identicas (mismo orden).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -I - <<'PY'
import re,sys
c=open("src/aafix/aafix.c",encoding="utf-8").read()
m=re.search(r"LATIN\[\]\s*=\s*((?:L\"[^\n]*\"\s*)+);",c)
s="".join(re.findall(r'L"((?:[^"\\]|\\.)*)"',m.group(1)))
a=re.sub(r"\\u([0-9a-fA-F]{4})",lambda x:chr(int(x.group(1),16)),s)
p=open("tools/validate-table.py",encoding="utf-8").read()
b=re.search(r'LATIN = \("([^"]*)"\)',p).group(1)
print(len(a),len(b))
if a!=b: print("FALLO: LATIN difiere\n",a,"\n",b); sys.exit(1)
print("OK: LATIN identica")
PY
