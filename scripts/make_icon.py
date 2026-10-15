"""Draws the MeetingOS app icon (1024x1024, no transparency).

Two panes side by side, like the live workspace: note lines on the left
and action-item checkmarks on the right, in MeetingOS's teal accent.
Run: python3 scripts/make_icon.py
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 4096  # draw big, then shrink for smooth edges
OUT = sys.argv[1] if len(sys.argv) > 1 else "AppAssets/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
BG_TOP, BG_BOTTOM = (22, 44, 58), (10, 22, 32)
PANE = (238, 243, 246)
LINE = (170, 186, 196)
ACCENT = (36, 107, 144)

img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):
    t = y / (S - 1)
    d.line([(0, y), (S, y)], fill=tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)))

shadow = Image.new("L", (S, S), 0)
ImageDraw.Draw(shadow).rounded_rectangle([560, 980, 3536, 3240], radius=260, fill=160)
img.paste((4, 10, 14), (0, 0), shadow.filter(ImageFilter.GaussianBlur(120)))
d = ImageDraw.Draw(img)

left = [520, 900, 1990, 3196]
right = [2106, 900, 3576, 3196]
for box in (left, right):
    d.rounded_rectangle(box, radius=200, fill=PANE)

# Notes: a title bar and text lines.
x0, x1 = left[0] + 200, left[2] - 200
d.rounded_rectangle([x0, 1140, x1 - 260, 1290], radius=75, fill=ACCENT)
for i, width in enumerate([1.0, 0.82, 0.94, 0.6, 0.88, 0.7]):
    y = 1480 + i * 250
    d.rounded_rectangle([x0, y, x0 + (x1 - x0) * width, y + 110], radius=55, fill=LINE)

# Action items: check circles with lines.
cx = right[0] + 300
for i, done in enumerate([True, True, False, False]):
    y = 1260 + i * 470
    r = 135
    if done:
        d.ellipse([cx - r, y - r, cx + r, y + r], fill=ACCENT)
        d.line([(cx - 65, y), (cx - 15, y + 55), (cx + 70, y - 55)], fill=PANE, width=60, joint="curve")
    else:
        d.ellipse([cx - r, y - r, cx + r, y + r], outline=ACCENT, width=50)
    d.rounded_rectangle([cx + 230, y - 55, right[2] - 220, y + 55], radius=55, fill=LINE)

img.resize((1024, 1024), Image.LANCZOS).save(OUT, "PNG")
print("Wrote", OUT)
