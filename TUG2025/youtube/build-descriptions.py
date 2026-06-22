#!/usr/bin/env python3
"""
Fetch the TUG 2025 abstracts from tug.org and turn each into a plain-text
YouTube description.

For every talk in talks.tsv it downloads
    https://tug.org/tug2025/abstracts/<name>.txt
(a TUGboat-style file: {author}{title}{abstract body}), extracts the third
brace group (the abstract body), converts the common (La)TeX / TUGboat macros
to readable text, and writes:
    abstracts-raw/<name>.txt   (verbatim source, for reference)
    desc/<token>.txt           (cleaned description used for upload)

The cleaning is best-effort. Any macro it does not know is reported at the end
and the leftover text is left for you to hand-edit in desc/<token>.txt before
uploading.  Re-run any time:  python3 build-descriptions.py
"""
import os, re, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://tug.org/tug2025/abstracts"
PAPERS_BASE = "https://tug.org/TUGboat/tb46-2"   # TUGboat 46:2 (TUG 2025 papers)
RAW  = os.path.join(HERE, "abstracts-raw")
DESC = os.path.join(HERE, "desc")

# word macros (control words) -> replacement text; a trailing space is absorbed
WORDS = {
    "LaTeX": "LaTeX", "TeX": "TeX", "XeLaTeX": "XeLaTeX", "LuaLaTeX": "LuaLaTeX",
    "LuaTeX": "LuaTeX", "XeTeX": "XeTeX", "pdfTeX": "pdfTeX", "ConTeXt": "ConTeXt",
    "MetaPost": "MetaPost", "MetaFont": "MetaFont", "METAFONT": "METAFONT",
    "BibTeX": "BibTeX", "BibLaTeX": "BibLaTeX", "biblatex": "biblatex",
    "XML": "XML", "SGML": "SGML", "HTML": "HTML", "SQL": "SQL", "PDF": "PDF",
    "CTAN": "CTAN", "DANTE": "DANTE", "TUB": "TUGboat", "acro": "",
    "Dash": "—", "dots": "…", "ldots": "…", "slash": "/",
    "TUG": "TUG", "AMS": "AMS", "API": "API",
    "xdp": "XDP", "tk": "TK", "KaTeX": "KaTeX", "MathML": "MathML",
}
# \name{arg} macros -> keep arg 1 (the text)
KEEP1 = ["texttt", "textit", "textbf", "textsf", "textrm", "emph", "hbox",
         "mbox", "text", "enquote", "textsc", "acro", "url", "verb", "code", "pkg"]
# \name{a}{b} macros -> keep one arg
KEEP_FIRST  = ["tbsurl", "href", "tbhref"]    # keep the URL / first arg
KEEP_SECOND = ["regularorprogramstring"]      # keep the program-mode (2nd) arg
# control words with no output
DROP_WORD = ["par", "noindent", "hanging", "smallskip", "medskip", "bigskip",
             "relax", "programnl", "penalty", "hfill", "centerline",
             "raggedright", "small", "footnotesize", "it", "bf", "tt", "rm",
             "sl", "leavevmode", "preprint", "hyph", "looseness"]

unknown = set()

def top_groups(s):
    """Return the list of top-level {...} group contents, in order."""
    out, depth, start = [], 0, None
    for i, c in enumerate(s):
        if c == '{':
            if depth == 0:
                start = i + 1
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                out.append(s[start:i])
    return out

def strip_args(text, names, keep_index):
    """Replace \\name{...}[{...}] keeping the keep_index-th brace argument."""
    for name in names:
        pat = re.compile(r'\\' + name + r'\s*')
        i = 0
        while True:
            m = pat.search(text, i)
            if not m:
                break
            j = m.end(); args = []
            while j < len(text) and text[j] == '{':
                depth, k = 0, j
                while k < len(text):
                    if text[k] == '{':
                        depth += 1
                    elif text[k] == '}':
                        depth -= 1
                        if depth == 0:
                            break
                    k += 1
                args.append(text[j + 1:k]); j = k + 1
            repl = args[keep_index] if len(args) > keep_index else (args[0] if args else "")
            text = text[:m.start()] + repl + text[j:]
            i = m.start() + len(repl)
    return text

def remove_defs(t):
    """Remove \\def\\name{...balanced...} definitions entirely."""
    out, i = [], 0
    pat = re.compile(r'\\def\s*\\[A-Za-z]+\s*\{')
    while True:
        m = pat.search(t, i)
        if not m:
            out.append(t[i:]); break
        out.append(t[i:m.start()])
        depth, k = 0, m.end() - 1
        while k < len(t):
            if t[k] == '{':
                depth += 1
            elif t[k] == '}':
                depth -= 1
                if depth == 0:
                    break
            k += 1
        i = k + 1
    return ''.join(out)

DROPSET = set(DROP_WORD)

def _wrepl(m):
    name = m.group(1)
    if name in WORDS:
        return WORDS[name]
    if name in DROPSET:
        return ' '
    unknown.add(name)
    return name

def clean(body):
    t = re.sub(r'\\\\%[ \t]*\n?[ \t]*', '', body)  # \\% line-join idiom (long URLs)
    t = remove_defs(t)
    t = re.sub(r'(?<!\\)%[^\n]*', '', t)   # strip TeX comments (% to end of line)
    # dimension / box macros that take a length
    t = re.sub(r'\\(?:kern|raise|lower|hskip|vskip|hspace|vspace)\s*-?[\d.]+\s*\w*', ' ', t)
    # dimen assignments and penalties
    t = re.sub(r'\\(?:hyphenpenalty|exhyphenpenalty|penalty|parindent|parskip|baselineskip)\s*=?\s*-?\d*\w*', ' ', t)
    # arg-keeping macros: {a}{b} before {a}, both before bare words
    t = strip_args(t, KEEP_SECOND, 1)
    t = strip_args(t, KEEP_FIRST, 0)
    t = strip_args(t, KEEP1, 0)

    # Protect explicit spacing as sentinels BEFORE macro processing, so a word
    # macro that absorbs its trailing space cannot swallow a real word break.
    NB, NL = '\x00', '\x01'           # hard space, hard line break
    t = t.replace('\\\\', NL)            # forced line break
    t = re.sub(r'\\[ \t\r\n,;:>]', NB, t)  # control space, line-break space, thin spaces
    t = t.replace('\\!', '')             # negative thin space
    t = t.replace('\\|', '')             # discretionary hyphen
    t = t.replace('\\-', '')             # discretionary hyphen
    t = t.replace('~', NB)               # non-breaking space

    # macros, left-to-right: known word -> text, drop-word -> space, else keep
    # the word (and record it for review); a control word absorbs one space.
    t = re.sub(r'\\([A-Za-z]+)[ \t]?', _wrepl, t)
    t = re.sub(r'\\(.)', r'\1', t)       # escaped punctuation \& \% \# \_ ...

    t = t.replace('---', '—').replace('--', '–')
    t = t.replace('{', '').replace('}', '')
    t = t.replace(NB, ' ').replace(NL, '\n')      # restore protected spacing

    # whitespace tidy: single newlines -> space, keep paragraph breaks
    t = re.sub(r'[ \t]*\n[ \t]*\n[ \t]*', '\n\n', t)
    t = re.sub(r'(?<!\n)\n(?!\n)', ' ', t)
    t = re.sub(r'[ \t]{2,}', ' ', t)
    t = re.sub(r'\n{3,}', '\n\n', t)
    return t.strip()

def load_tsv(name):
    out = {}
    p = os.path.join(HERE, name)
    if os.path.exists(p):
        with open(p) as f:
            for line in f:
                line = line.rstrip('\n')
                if not line or line.startswith('#') or '\t' not in line:
                    continue
                k, v = line.split('\t', 1)
                out[k.strip()] = v.strip()
    return out


def write_desc(token, desc, paper_pdf):
    """Write desc/<token>.txt: a 'Paper:' link line on top (if any), then the
    abstract."""
    parts = []
    if paper_pdf and paper_pdf != '-':
        parts.append(f"Paper (TUGboat 46:2): {PAPERS_BASE}/{paper_pdf}")
    if desc:
        parts.append(desc)
    text = "\n\n".join(parts)
    with open(os.path.join(DESC, token + '.txt'), 'w') as f:
        f.write(text + ('\n' if text else ''))
    return text


def main():
    os.makedirs(RAW, exist_ok=True); os.makedirs(DESC, exist_ok=True)
    papers = load_tsv("papers.tsv")
    rows = []
    with open(os.path.join(HERE, "talks.tsv")) as f:
        for line in f:
            line = line.rstrip('\n')
            if not line or line.startswith('#'):
                continue
            token, absname = line.split('\t')
            rows.append((token, absname.strip()))
    for token, absname in rows:
        paper = papers.get(token, '-')
        tag = "  +paper" if paper not in ('', '-') else ""
        if absname == '-':
            write_desc(token, '', paper)
            print(f"[ -- ] {token}: no abstract{tag}")
            continue
        url = f"{BASE}/{absname}.txt"
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            src = urllib.request.urlopen(req, timeout=30).read().decode('utf-8', 'replace')
        except Exception as e:
            print(f"[FAIL] {token}: {url}: {e}")
            # don't clobber an existing good description on a transient failure;
            # only write a paper-only fallback if there is nothing there yet.
            p = os.path.join(DESC, token + '.txt')
            if not (os.path.exists(p) and os.path.getsize(p) > 0):
                write_desc(token, '', paper)
            continue
        with open(os.path.join(RAW, absname + '.txt'), 'w') as f:
            f.write(src)
        groups = top_groups(src)
        if len(groups) >= 3:
            body = groups[2]
        else:
            # plain-text abstract (e.g. a dashed "----\nTitle\n----" header
            # followed by the body); drop the header block if present.
            m = re.search(r'-{3,}\s*\n.*?\n-{3,}\s*\n+(.*)$', src, re.S)
            body = m.group(1) if m else src
        desc = clean(body)
        text = write_desc(token, desc, paper)
        print(f"[ ok ] {token}  ({len(text)} chars)  <- {absname}.txt{tag}")
    if unknown:
        print("\nMacros left as plain words (review desc/*.txt if any look wrong):")
        print("  " + ", ".join("\\" + u for u in sorted(unknown)))

if __name__ == '__main__':
    main()
