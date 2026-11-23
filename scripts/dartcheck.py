import sys, pathlib
PAIRS={'(' :')','[':']','{':'}'}
def scan(s, path):
    i=0; n=len(s); stack=[]
    def string(i, q, raw=False):
        # returns index after closing quote; handles ${...} and $ident
        triple = s.startswith(q*3, i)
        qq = q*3 if triple else q
        i += len(qq)
        while i<n:
            if s.startswith(qq, i): return i+len(qq)
            c=s[i]
            if c=='\\' and not raw: i+=2; continue
            if c=='$' and s[i+1:i+2]=='{' and not raw:
                depth=1; i+=2
                while i<n and depth:
                    c=s[i]
                    if c in '\'"': i=string(i,c); continue
                    if c=='{': depth+=1
                    elif c=='}': depth-=1
                    i+=1
                continue
            if c=='\n' and not triple: raise SyntaxError(f"{path}: unterminated string near offset {i}")
            i+=1
        raise SyntaxError(f"{path}: unterminated string")
    line=1
    while i<n:
        c=s[i]
        if s.startswith('//',i):
            while i<n and s[i]!='\n': i+=1
            continue
        if s.startswith('/*',i):
            j=s.find('*/',i+2); i=n if j<0 else j+2; continue
        if c in '\'"':
            raw = i>0 and s[i-1]=='r' and not (i>1 and (s[i-2].isalnum() or s[i-2]=='_'))
            i=string(i,c,raw); continue
        if c in PAIRS: stack.append((c,s.count('\n',0,i)+1))
        elif c in ')]}':
            if not stack or PAIRS[stack[-1][0]]!=c: raise SyntaxError(f"{path}: unmatched '{c}' at line {s.count(chr(10),0,i)+1}")
            stack.pop()
        i+=1
    if stack: raise SyntaxError(f"{path}: unclosed '{stack[-1][0]}' opened at line {stack[-1][1]}")
bad=0
for p in sorted(pathlib.Path('.').rglob('*.dart')):
    try: scan(p.read_text(), str(p))
    except SyntaxError as e: print("FAIL", e); bad+=1
print("files checked:", len(list(pathlib.Path('.').rglob('*.dart'))), "failures:", bad)
