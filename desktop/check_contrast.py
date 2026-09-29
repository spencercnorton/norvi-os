#!/usr/bin/env python3
"""Assert the window-glass alphas keep primary text above WCAG AA.

The alpha is the one number in each stylesheet that can silently break
accessibility: lower it and text starts floating over the desktop. Run this
before changing it.  `python3 desktop/check_contrast.py`

BOTH stylesheets are read. They carry independent alphas under different colour
tokens, so checking only gtk4.css let an unsafe gtk3.css value through as long
as gtk4.css stayed at 0.72 — and the GTK3 half is what a GTK3 file manager
such as Nemo actually renders.
"""
import re, sys, pathlib

AA = 4.5                      # accessibility.primary_text_minimum_contrast
# (surface_bg, text_fg, fg_alpha). GTK4 values are libadwaita 1.9 tokens; GTK3
# values were read off the live themes with Gtk.StyleContext.lookup_color, since
# GTK3 has no published token set and Yaru is not Adwaita.
SCHEMES = {
    "gtk4 light": (0xFA, 0x00, 0.8),   # @window_bg_color / @window_fg_color rgba(0,0,0,.8)
    "gtk4 dark":  (0x24, 0xFF, 1.0),
    "gtk3 light": (250,  61,  1.0),    # Yaru-purple @theme_bg_color / @theme_fg_color
    "gtk3 dark":  (44,   247, 1.0),    # Yaru-purple-dark
}
BACKDROPS = {"black": 0, "mid grey": 128, "white": 255}
# stylesheet -> the colour token its window-glass rule is written against
STYLESHEETS = {"gtk3.css": "@theme_bg_color", "gtk4.css": "@window_bg_color"}


def _lin(c):
    c /= 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def contrast(a, b):
    la, lb = _lin(a) + 0.05, _lin(b) + 0.05
    return max(la, lb) / min(la, lb)


def worst(alpha):
    """Lowest text/background contrast across both schemes and all backdrops."""
    out = []
    for scheme, (bg, fg, fg_a) in SCHEMES.items():
        for name, back in BACKDROPS.items():
            surface = alpha * bg + (1 - alpha) * back
            text = fg_a * fg + (1 - fg_a) * surface   # fg may be translucent
            out.append((contrast(surface, text), scheme, name))
    return min(out)


# Menus are one dark plate in light and dark style alike, under white text, and
# GTK draws no blur behind them, so the plate's alpha alone keeps the labels
# readable on a white wallpaper (the Shell's .22 token would give 1.5:1). A
# hovered item adds a white wash. Worked on 50, the plate's lightest channel,
# so the estimate errs toward less contrast.
PLATE = r"background-color:\s*rgba\(45,\s*45,\s*50,\s*([\d.]+)\)"
WASH = r":hover\s*\{[^}]*background-color:\s*rgba\(255,\s*255,\s*255,\s*([\d.]+)\)"


def menu_worst(plate, wash):
    out = []
    for name, back in BACKDROPS.items():
        surface = plate * 50 + (1 - plate) * back
        for state, s in (("menu", surface), ("hovered item", wash * 255 + (1 - wash) * surface)):
            out.append((contrast(s, 255), state, name))
    return min(out)


def menus_from_stylesheets():
    """(lowest plate alpha, strongest hover wash) per stylesheet."""
    out = {}
    for name in STYLESHEETS:
        css = re.sub(r"/\*.*?\*/", "", (pathlib.Path(__file__).parent / name).read_text(), flags=re.S)
        plates, washes = re.findall(PLATE, css), re.findall(WASH, css)
        assert plates and washes, f"no menu plate or hover wash found in {name}"
        out[name] = (min(map(float, plates)), max(map(float, washes)))
    return out


def alphas_from_stylesheets():
    """Every window-glass alpha in the layer, keyed by stylesheet."""
    out = {}
    for name, token in STYLESHEETS.items():
        css = (pathlib.Path(__file__).parent / name).read_text()
        # These stylesheets discuss `window.background` at length in prose, so
        # strip comments first or a sentence can be mistaken for the rule.
        css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
        # `[^{}]*` tolerates a SCOPED selector. gtk3.css carries
        # `window.background:not(.desktopwindow)` to keep the glass off DING's
        # desktop window; the original `\s*\{` matched only the bare selector, so
        # scoping it made this gate fail and install-desktop.sh refuse to run.
        # Anchored on the rule's own brace, so it cannot run into the next block.
        m = re.search(r"window\.background[^{}]*\{[^}]*alpha\(" + re.escape(token)
                      + r",\s*([\d.]+)\)", css)
        assert m, f"no window.background alpha rule found in {name}"
        out[name] = float(m.group(1))
    return out


if __name__ == "__main__":
    alphas = alphas_from_stylesheets()
    # Each alpha is judged against BOTH toolkits' schemes, not just its own:
    # the stricter reading, and it costs nothing while the two values agree.
    for name in sorted(alphas):
        c, scheme, back = worst(alphas[name])
        print(f"  {name:9s} alpha {alphas[name]:.2f}  worst {c:5.2f}:1"
              f"  ({scheme} scheme, {back} backdrop)  {'PASS' if c >= AA else 'FAIL'}")
    for a in (0.55, 0.30):
        c, scheme, back = worst(a)
        print(f"  {'(would be)':9s} alpha {a:.2f}  worst {c:5.2f}:1"
              f"  ({scheme} scheme, {back} backdrop)  {'PASS' if c >= AA else 'FAIL'}")
    for name in sorted(alphas):
        c, scheme, back = worst(alphas[name])
        assert c >= AA, (f"{name} alpha {alphas[name]} gives {c:.2f}:1 in {scheme} "
                         f"on {back} — below AA {AA}")
    for name, (plate, wash) in sorted(menus_from_stylesheets().items()):
        c, state, back = menu_worst(plate, wash)
        print(f"  {name:9s} menu plate {plate:.2f}  worst {c:5.2f}:1"
              f"  ({state}, {back} backdrop)  {'PASS' if c >= AA else 'FAIL'}")
        assert c >= AA, (f"{name} menu plate {plate} gives {c:.2f}:1 on {back} — below AA {AA}")
    # floor: the lowest alpha that still passes, to 0.01
    floor = next(a / 100 for a in range(1, 101) if worst(a / 100)[0] >= AA)
    shown = ", ".join(f"{n} {alphas[n]}" for n in sorted(alphas))
    print(f"\nOK: {shown} — all pass AA {AA}:1. Floor is {floor:.2f} — do not go below.")
