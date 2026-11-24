#!/usr/bin/env python3
"""String catalog helper for NoFeed.

    scripts/l10n.py sync <derived-data-dir>   pull new keys from a build into the catalogs
    scripts/l10n.py missing [out.json]        list keys without every shipped translation
    scripts/l10n.py merge <in.json>           validate and merge translations

`merge` reads {"<lang>": {"<key>": value}} where value is a string, or
{"one": .., "other": ..} for a key with English plural variations. Every format
specifier must match the English, or nothing is written.
"""
import json, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGS = [ROOT / "Shared/Localizable.xcstrings", ROOT / "NoFeed/AppShortcuts.xcstrings"]
LANGS = ["es", "fr", "de", "ja", "pt-BR"]
SPEC = re.compile(r"%(?:\d+\$)?(lld|ld|d|@)")


def load(p): return json.loads(p.read_text())


def dump(p, d):
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2, sort_keys=True).replace('": ', '" : ') + "\n")


def english(key, entry):
    en = entry.get("localizations", {}).get("en", {})
    if "variations" in en:
        return {f: v["stringUnit"]["value"] for f, v in en["variations"]["plural"].items()}
    return en.get("stringUnit", {}).get("value", key)


def specs(text):
    return sorted("lld" if t in ("lld", "ld", "d") else t for t in SPEC.findall(text))


def sync(derived):
    files = [str(p) for p in pathlib.Path(derived).rglob("*.stringsdata") if "Tests" not in str(p)]
    shortcuts = [f for f in files if f.endswith("ExtractedAppShortcutsMetadata.stringsdata")]
    others = [f for f in files if f not in shortcuts]
    for catalog, data in ((CATALOGS[0], others), (CATALOGS[1], shortcuts)):
        if not data:
            continue
        args = ["xcrun", "xcstringstool", "sync", str(catalog)]
        for f in data:
            args += ["--stringsdata", f]
        subprocess.run(args, check=True)
        d = load(catalog)
        stale = [k for k, v in d["strings"].items() if v.get("extractionState") == "stale"]
        for k in stale:
            del d["strings"][k]
        dump(catalog, d)
        print(f"{catalog.name}: {len(d['strings'])} keys, removed stale {stale}")


def missing(out=None):
    rows = []
    for catalog in CATALOGS:
        for k, v in sorted(load(catalog)["strings"].items()):
            if v.get("shouldTranslate") is False or not k.strip("%@ld"):
                continue
            have = v.get("localizations", {})
            lacking = [l for l in LANGS if l not in have]
            if lacking:
                rows.append({"key": k, "english": english(k, v), "comment": v.get("comment"), "lacking": lacking})
    if out:
        pathlib.Path(out).write_text(json.dumps(rows, ensure_ascii=False, indent=1))
    for r in rows:
        print(repr(r["key"]))
    print(f"{len(rows)} keys need translations")


def merge(path):
    incoming = json.loads(pathlib.Path(path).read_text())
    docs = {c: load(c) for c in CATALOGS}
    errors, merged = [], 0
    for lang, values in incoming.items():
        for key, value in values.items():
            catalog = next((c for c in CATALOGS if key in docs[c]["strings"]), None)
            if catalog is None:
                errors.append(f"{lang} {key!r}: not in any catalog"); continue
            entry = docs[catalog]["strings"][key]
            en = english(key, entry)
            if isinstance(en, dict):
                forms = ["other"] if lang == "ja" else ["one", "other"]
                if not isinstance(value, dict) or any(f not in value for f in forms):
                    errors.append(f"{lang} {key!r}: needs plural forms {forms}"); continue
                if any(specs(value[f]) != specs(en["other"]) for f in forms):
                    errors.append(f"{lang} {key!r}: specifiers differ"); continue
                loc = {"variations": {"plural": {f: {"stringUnit": {"state": "translated", "value": value[f]}} for f in forms}}}
            elif catalog == CATALOGS[1]:
                if not isinstance(value, list) or any(v.count("${applicationName}") != 1 for v in value):
                    errors.append(f"{lang} {key!r}: phrases need ${{applicationName}} once each"); continue
                loc = {"stringSet": {"state": "translated", "values": value}}
            else:
                if not isinstance(value, str) or specs(value) != specs(en):
                    errors.append(f"{lang} {key!r}: specifiers differ from {en!r}"); continue
                loc = {"stringUnit": {"state": "translated", "value": value}}
            entry.setdefault("localizations", {})[lang] = loc
            merged += 1
    for e in errors:
        print("ERR", e)
    if errors:
        sys.exit(1)
    for c, d in docs.items():
        dump(c, d)
    print(f"merged {merged} translations")


if __name__ == "__main__":
    cmd, *rest = sys.argv[1:] or ["help"]
    {"sync": sync, "missing": missing, "merge": merge}.get(cmd, lambda *_: print(__doc__))(*rest)
