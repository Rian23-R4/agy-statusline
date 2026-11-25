#!/usr/bin/env bash
# AGY statusline, ported from Rian's Mac [CC] style: colored lines, dot bars, reset times.
# AGY pipes StatusLineData JSON on stdin (schema: antigravity.google/docs/cli/statusline).
input=$(cat 2>/dev/null)
printf '%s' "$input" | python3 -c "
import sys, json, os, datetime

try:
    d = json.load(sys.stdin)
except Exception:
    d = {}

G, Y, R, DIM, DIMMER, X = '\033[32m', '\033[33m', '\033[31m', '\033[38;5;248m', '\033[38;5;240m', '\033[0m'
C_MODEL, C_DIR = '\033[38;5;117m', '\033[38;5;31m'
SEP = f' {DIMMER}|{X} '

def pct_color(p, used=True):
    if used:
        return G if p < 60 else (Y if p < 80 else R)
    return G if p > 50 else (Y if p > 20 else R)

def dots(p, used=True):
    n = min(14, int(p * 14 / 100))
    bar = ''
    for i in range(1, 15):
        if i <= n:
            if used:
                c = 82 if i <= 3 else 118 if i <= 6 else 226 if i <= 9 else 208 if i <= 11 else 196
            else:
                c = 196 if i <= 3 else 208 if i <= 6 else 226 if i <= 9 else 118 if i <= 11 else 82
            bar += f'\033[38;5;{c}m●\033[0m'
        else:
            bar += '\033[38;5;238m○\033[0m'
    return bar

def fmt_reset(secs):
    if not isinstance(secs, (int, float)) or secs <= 0:
        return ''
    secs = int(secs)
    dd, rem = divmod(secs, 86400)
    h, m = rem // 3600, (rem % 3600) // 60
    dt = datetime.datetime.now() + datetime.timedelta(seconds=secs)
    date_s = dt.strftime('%d %b')
    if dd >= 1:
        return f'{dd}d {h}h · {date_s}'
    if h:
        return f'{h}h{m:02d}m'
    return f'{m}m'

model = (d.get('model') or {}).get('display_name') or '?'
effort = (d.get('model') or {}).get('effort') or ''
cdir = (d.get('workspace') or {}).get('current_dir') or ''
cdir = cdir.replace(os.path.expanduser('~'), '~')
parts = cdir.split('/')
short = '/'.join(parts[-2:]) if len(parts) > 3 else cdir
state = d.get('agent_state') or ''

ctx = d.get('context_window') or {}
up = ctx.get('used_percentage')
if isinstance(up, (int, float)):
    tk = ctx.get('total_input_tokens') or 0
    sz = ctx.get('context_window_size') or 0
    col = pct_color(up, used=True)
    ctx_s = f'🧠 {col}{up:.0f}%{X}'
    if sz:
        ctx_s += f' {col}{tk//1000}k/{sz//1000}k{X}'
else:
    ctx_s = ''

q = d.get('quota') or {}

def bucket(k, label):
    v = (q.get(k) or {}).get('remaining_fraction')
    if not isinstance(v, (int, float)):
        return ''
    p = v * 100
    col = pct_color(p, used=False)
    reset = fmt_reset((q.get(k) or {}).get('reset_in_seconds'))
    row = f'{col}{label}{X} {dots(p, used=False)} {col}{p:.0f}%{X}'
    if reset:
        row += f' {DIMMER}⏳{X} {col}{reset}{X}'
    return row

mid = ((d.get('model') or {}).get('id') or '').lower()
line1 = f'🤖 {C_MODEL}{model}{X}'
if effort:
    line1 += f'{SEP}\033[38;5;220m{effort}{X}'
if ctx_s:
    line1 += SEP + ctx_s
if state:
    st = G if state in ('idle', 'reviewing') else (Y if state in ('working', 'tool_use') else DIM)
    line1 += SEP + f'{st}{state}{X}'
mode = d.get('cycle_mode') or ''
if mode:
    line1 += SEP + f'\033[38;5;213m⇥ {mode}{X}'

line2 = f'📁 {C_DIR}{short}{X}'
rows = [line1, line2]
if 'gemini' in mid:
    order = [('gemini-5h', '⚡G 5h'), ('gemini-weekly', '📅G wk'), ('3p-5h', '⚡C 5h'), ('3p-weekly', '📅C wk')]
else:
    order = [('3p-5h', '⚡C 5h'), ('3p-weekly', '📅C wk'), ('gemini-5h', '⚡G 5h'), ('gemini-weekly', '📅G wk')]
for k, label in order:
    r = bucket(k, label)
    if r:
        rows.append(r)

print('\n'.join(rows), end='')
"
