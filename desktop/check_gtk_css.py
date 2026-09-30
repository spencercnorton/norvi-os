#!/usr/bin/env python3
"""Parse gtk3.css and gtk4.css with the real GTK parsers; fail on any error.

A malformed rule does not raise and does not stop an app. GTK prints a warning,
skips the rule and carries on looking normal, so a stylesheet can be installed
and style nothing without anyone noticing. `python3 desktop/check_gtk_css.py`

GTK 3 and GTK 4 cannot be loaded into one process (the second
`gi.require_version` raises), so each version parses in its own interpreter.
A version that cannot load there fails the check: a partial parse that exits 0
is a false green. `--allow-missing-toolkit` accepts that gap for local use.
Needs python3-gi, gir1.2-gtk-3.0 and gir1.2-gtk-4.0.
"""
import subprocess, sys, pathlib

HERE = pathlib.Path(__file__).resolve().parent
FILES = {"3.0": HERE / "gtk3.css", "4.0": HERE / "gtk4.css"}
UNAVAILABLE = 2

CHILD = """
import sys
try:
    import gi
    gi.require_version("Gtk", sys.argv[1])
    from gi.repository import Gtk
except Exception as exc:
    print(exc, file=sys.stderr)
    sys.exit(2)
errors = []
def on_error(_provider, section, error):
    # GTK 3 sections know their line; GTK 4 sections know their location.
    line = (section.get_start_line() if hasattr(section, "get_start_line")
            else section.get_start_location().lines)
    errors.append(f"{line + 1}: {error.message}")
provider = Gtk.CssProvider()
provider.connect("parsing-error", on_error)
text = open(sys.argv[2]).read()
try:
    if sys.argv[1] == "3.0":
        provider.load_from_data(text.encode())  # also raises on the first error
    else:
        provider.load_from_string(text)
except Exception as exc:
    if not errors:  # GTK 3 raises for the error its signal already reported
        errors.append(f"?: {exc}")
print("\\n".join(errors), file=sys.stderr)
sys.exit(1 if errors else 0)
"""


def check(version, path):
    proc = subprocess.run([sys.executable, "-c", CHILD, version, str(path)],
                          capture_output=True, text=True)
    name = path.relative_to(HERE.parent)
    if proc.returncode == 0:
        print(f"OK    {name} parses clean with GTK {version}")
    elif proc.returncode == UNAVAILABLE:
        print(f"SKIP  GTK {version} unavailable, {name} NOT verified: {proc.stderr.strip()}",
              file=sys.stderr)
    else:
        for line in proc.stderr.strip().splitlines():
            print(f"ERROR {name}:{line}", file=sys.stderr)
    return proc.returncode


results = [check(v, p) for v, p in FILES.items()]
allow_missing = "--allow-missing-toolkit" in sys.argv[1:]
sys.exit(1 if any(r == 1 or (r == UNAVAILABLE and not allow_missing) for r in results) else 0)
