#!/usr/bin/env python3
"""Convert a Joplin 'MD + Front Matter' export into an Obsidian vault.

Handles (as found in Erik's 2026-09-27 export):
  - _resources/<hash>.<ext>  -> _attachments/<hash>.<ext>, links rewritten relative to each note
  - relative links to other notes (foo.md, ./foo, with optional #anchor) -> [[Wikilink]] (unambiguous: no dup titles)
  - frontmatter title vs filename mismatches (apostrophes sanitized to '_') -> add aliases
Usage:
  joplin_to_obsidian.py <src_export_dir> <dst_vault_dir> [--apply]
Without --apply it only prints what it would do (dry run).

Created by Dax (Hermes Agent)
"""
import os, re, sys, shutil, urllib.parse

SRC, DST = sys.argv[1], sys.argv[2]
APPLY = '--apply' in sys.argv

stats = {'notes': 0, 'img_rewritten': 0, 'note_links_wikified': 0,
         'aliases_added': 0, 'other_links_kept': 0, 'resources_copied': 0}

# ---- pass 0: index notes by stem (title-uniqueness already verified) ----
notes = []  # (src_path, rel_dir)
for dirpath, dirs, files in os.walk(SRC):
    dirs[:] = [d for d in dirs if d != '_resources']
    for f in files:
        if f.endswith('.md'):
            notes.append((os.path.join(dirpath, f), os.path.relpath(dirpath, SRC)))
by_stem = {os.path.splitext(os.path.basename(p))[0]: p for p, _ in notes}

def read(p):
    with open(p, encoding='utf-8', errors='replace') as fh:
        return fh.read()

def fm_title(text):
    m = re.match(r'\A---\n(.*?)\n---\n', text, re.S)
    if m:
        t = re.search(r'^title:\s*(.+)$', m.group(1), re.M)
        if t:
            return t.group(1).strip()
    return None

def rel_attach(note_rel_dir, fname):
    """Relative link from the DESTINATION note dir to _attachments/fname, URL-safe."""
    dst_note_dir = os.path.join(DST, note_rel_dir)
    rel = os.path.relpath(os.path.join(DST, '_attachments', fname), dst_note_dir)
    return urllib.parse.quote(rel)

for src_path, rel_dir in notes:
    text = read(src_path)
    note_dir = os.path.dirname(src_path)
    out = text

    # 1) image/resource links: [..]( <anything>_resources/<hash>.<ext> )
    def img_sub(m):
        bang, label, url = m.group(1), m.group(2), m.group(3)
        path = urllib.parse.unquote(url.split('#')[0])
        cand = os.path.normpath(os.path.join(note_dir, path))
        fname = os.path.basename(cand)
        if os.path.isfile(cand) and '_resources' in cand.split(os.sep):
            stats['img_rewritten'] += 1
            return f'{bang}[{label}]({rel_attach(rel_dir, fname)})'
        return m.group(0)
    out = re.sub(r'(!?)\[([^\]]*)\]\(([^)]*_resources/[^)]+)\)', img_sub, out)

    # 2) note-to-note links: [label](path.md#anchor) or [label](./Name)
    def note_sub(m):
        label, url = m.group(2), m.group(4)
        if url.startswith(('mailto:', 'javascript:')) or url.startswith('http'):
            stats['other_links_kept'] += 1
            return m.group(0)
        plain = urllib.parse.unquote(url.split('#')[0])
        if not plain:
            return m.group(0)
        s = os.path.basename(plain)
        if s.endswith('.md'):
            s = s[:-3]
        if s in by_stem:  # titles verified unique across the vault
            stats['note_links_wikified'] += 1
            anchor = ('#' + urllib.parse.unquote(url.split('#', 1)[1])) if '#' in url else ''
            return f'[[{s}{anchor}]]' if label in (s, '') else f'[[{s}{anchor}|{label}]]'
        return m.group(0)
    out = re.sub(r'(\[)([^\]]*)(\]\()((?!(?:https?:)?//)[^)]+)(\))', note_sub, out)

    # 3) aliases where filename stem differs from frontmatter title
    title = fm_title(text)
    stem = os.path.splitext(os.path.basename(src_path))[0]
    if title and title != stem:
        alias = title.strip().strip("'").strip()
        if alias and alias != stem:
            m = re.match(r'\A---\n', out)
            if m and not re.search(r'^aliases:', out, re.M):
                # insert a proper YAML aliases list right after the title line
                def _add_alias(mm):
                    esc = alias.replace('\\', '\\\\').replace('"', '\\"')
                    return mm.group(1) + '\naliases: ["' + esc + '"]'
                out2 = re.sub(r'(^title:.*$)', _add_alias, out, count=1, flags=re.M)
                if out2 != out:
                    out = out2
                    stats['aliases_added'] += 1

    dst_path = os.path.join(DST, rel_dir, os.path.basename(src_path))
    if APPLY:
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        with open(dst_path, 'w', encoding='utf-8') as fh:
            fh.write(out)
    stats['notes'] += 1

# 4) copy _resources -> _attachments
src_res = os.path.join(SRC, '_resources')
if os.path.isdir(src_res):
    if APPLY:
        os.makedirs(os.path.join(DST, '_attachments'), exist_ok=True)
    for f in os.listdir(src_res):
        stats['resources_copied'] += 1
        if APPLY:
            shutil.copy2(os.path.join(src_res, f), os.path.join(DST, '_attachments', f))

print(f"mode: {'APPLY' if APPLY else 'DRY RUN'}")
for k, v in stats.items():
    print(f"  {k}: {v}")
