from pathlib import Path
from PIL import Image, ImageDraw
import math
import subprocess

root = Path(__file__).resolve().parents[1]
iconset = root / "Resources" / "AppIcon.iconset"
iconset.mkdir(parents=True, exist_ok=True)
base = 1024
im = Image.new("RGBA", (base, base), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
for y in range(80, 944):
    t = (y - 80) / 864
    color = (int(95 + 25 * t), int(105 + 35 * t), int(245 + 8 * t), 255)
    d.line((80, y, 944, y), fill=color)
mask = Image.new("L", (base, base), 0)
ImageDraw.Draw(mask).rounded_rectangle((80, 80, 944, 944), radius=205, fill=255)
im.putalpha(mask)
d = ImageDraw.Draw(im)
d.rounded_rectangle((212, 300, 812, 748), radius=85, fill=(18, 23, 43, 255))
d.polygon([(366, 300), (420, 224), (604, 224), (658, 300)], fill=(18, 23, 43, 255))
d.ellipse((330, 368, 694, 732), fill=(102, 126, 255, 255))
d.ellipse((377, 415, 647, 685), fill=(19, 26, 50, 255))
for i in range(6):
    a = math.radians(i * 60 - 15)
    b = math.radians(i * 60 + 34)
    c = math.radians(i * 60 + 80)
    p1 = (512 + 132 * math.cos(a), 550 + 132 * math.sin(a))
    p2 = (512 + 132 * math.cos(b), 550 + 132 * math.sin(b))
    p3 = (512 + 58 * math.cos(c), 550 + 58 * math.sin(c))
    d.polygon([p1, p2, p3, (512, 550)], fill=(117 + i * 4, 139 + i * 3, 255, 255))
d.ellipse((478, 516, 546, 584), fill=(18, 24, 46, 255))
d.ellipse((720, 354, 760, 394), fill=(255, 101, 117, 255))
for size, suffix in [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"), (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")]:
    im.resize((size, size), Image.Resampling.LANCZOS).save(iconset / f"icon_{suffix}.png")
subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(root / "Resources" / "AppIcon.icns")], check=True)
print(root / "Resources" / "AppIcon.icns")
