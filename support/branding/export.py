"""Render every Duck Share icon the app ships, from duck.py. Run: python export.py <app_dir>"""
import io, sys, cairosvg
from PIL import Image
import duck

APP = sys.argv[1]
B, INK, WHITE = duck.BLUE, "#1C1B1F", "#FFFFFF"

def png(svg, size):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size))).convert("RGBA")

def body(col, scale=1.0, ring=True):
    return f'<g transform="translate(256 256) scale({scale}) translate(-256 -256)">{duck.mark(col, ring)}</g>'

def wrap(inner):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{inner}</svg>'

def tile(bg, shape="rect", scale=0.78, inset=0, radius=0):
    """Brand tile: white mark on blue. inset/radius for macOS-style padded squircle."""
    s = 512 - 2 * inset
    bgel = (f'<circle cx="256" cy="256" r="{s/2}" fill="{bg}"/>' if shape == "circle"
            else f'<rect x="{inset}" y="{inset}" width="{s}" height="{s}" rx="{radius}" fill="{bg}"/>')
    return wrap(bgel + body(WHITE, scale * s / 512))

def badge(kind):
    col, glyph = (("#34C759", '<path d="M418 82 L436 100 L466 64" fill="none" stroke="#fff" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>')
                  if kind == "success" else
                  ("#FF3B30", '<path d="M442 56 V90" stroke="#fff" stroke-width="16" stroke-linecap="round"/><circle cx="442" cy="110" r="9" fill="#fff"/>'))
    return f'<circle cx="442" cy="82" r="58" fill="{col}"/>{glyph}'

def save(im, path, rgb=False):
    (im.convert("RGB") if rgb else im).save(f"{APP}/{path}")

# --- in-app logos (logo-512 is tinted by ColorFiltered, so only alpha matters) ---
for n in (512, 256, 128):
    save(png(wrap(body(B)), n), f"assets/img/logo-{n}.png")
save(png(wrap(body(WHITE)), 512), "assets/img/logo-512-white.png")
# tray: ring-less mark reads better at 32px
mark = lambda col: wrap(body(col, 1.35, ring=False))
save(png(mark(B), 32), "assets/img/logo-32.png")
save(png(mark(WHITE), 32), "assets/img/logo-32-white.png")
save(png(mark(INK), 32), "assets/img/logo-32-black.png")
ico_sizes = [(s, s) for s in (16, 32, 48, 64, 128, 256)]
png(wrap(body(B)), 256).save(f"{APP}/assets/img/logo.ico", sizes=ico_sizes)

# --- Android ---
res = f"{APP}/android/app/src/main/res"
for d, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    fg = px * 108 // 48
    png(tile(B, radius=96), px).save(f"{res}/mipmap-{d}/ic_launcher.png")
    png(wrap(body(WHITE, 0.62)), fg).save(f"{res}/mipmap-{d}/ic_launcher_foreground.png")
    png(wrap(body("#000000", 0.62)), fg).save(f"{res}/mipmap-{d}/ic_launcher_monochrome.png")
    png(wrap(body(WHITE, 0.62)), fg).save(f"{res}/mipmap-{d}/ic_launcher_quicktile_foreground.png")
png(tile(B, shape="circle"), 192).save(f"{res}/mipmap-xxxhdpi/ic_launcher_round.png")
banner_svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180">'
              f'<rect width="320" height="180" fill="{WHITE}"/>'
              f'<g transform="translate(110 8) scale(0.195)">{duck.mark(B)}</g>'
              f'<text x="160" y="158" font-family="sans-serif" font-weight="bold" font-size="32" text-anchor="middle" fill="{INK}">Duck Share</text></svg>')
banner = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=banner_svg.encode()))).convert("RGBA")
banner.save(f"{res}/drawable/banner.png")

# --- iOS: full bleed, no alpha (App Store rejects alpha) ---
ios = f"{APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
for name, px in {"1024": 1024, "20": 20, "20@2x": 40, "20@3x": 60, "29": 29, "29@2x": 58, "29@3x": 87, "40": 40,
                 "40@2x": 80, "40@3x": 120, "60@2x": 120, "60@3x": 180, "76": 76, "76@2x": 152, "83.5@2x": 167}.items():
    png(tile(B), px).convert("RGB").save(f"{ios}/Icon-App-{name}.png")

# --- macOS: padded squircle (Big Sur grid: 824/1024) + status badges ---
mac = f"{APP}/macos/Runner/Assets.xcassets"
mac_svg = tile(B, inset=50, radius=92)
for px in (16, 32, 64, 128, 256, 512, 1024):
    png(mac_svg, px).save(f"{mac}/AppIcon.appiconset/logo-1024-mac-{px}.png")
for kind, folder in (("success", "AppIconWithSuccessMark"), ("error", "AppIconWithErrorMark")):
    png(mac_svg.replace("</svg>", badge(kind) + "</svg>"), 256).save(f"{mac}/{folder}.imageset/logo-1024-mac-256.png")
png(mark("#000000"), 32).save(f"{mac}/StatusBarItemIcon.imageset/logo-32-black.png")

# --- Windows ---
png(tile(B, radius=96), 256).save(f"{APP}/windows/runner/resources/app_icon.ico", sizes=ico_sizes)
print("exported")
