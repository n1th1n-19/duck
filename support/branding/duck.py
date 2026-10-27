"""Duck logo: LocalSend-style 8-segment ring + rubber duck. One source for every asset."""
import math
C, R, HALF, W = 256, 184, 14, 34
BLUE = "#1E6FD9"

def _seg(t):
    a1, a2 = math.radians(t - HALF), math.radians(t + HALF)
    return (f"M{C+R*math.cos(a1):.1f} {C+R*math.sin(a1):.1f}"
            f"A{R} {R} 0 0 1 {C+R*math.cos(a2):.1f} {C+R*math.sin(a2):.1f}")

RING = " ".join(_seg(45 * i) for i in range(8))
# body + head in one path; eye is an evenodd hole so it stays transparent
DUCK = ("M150 240 Q150 226 164 230 C184 236 198 248 222 252 L262 252 C250 238 244 222 244 206 "
        "C244 176 268 152 298 152 C328 152 352 176 352 206 C352 222 346 236 336 246 "
        "C362 252 374 274 366 298 C354 332 314 346 258 346 C196 346 158 322 152 288 "
        "C148 268 150 254 150 240 Z "
        "M316 208 A10 10 0 1 0 296 208 A10 10 0 1 0 316 208 Z")
BILL = "M340 194 C362 186 386 192 394 206 C384 222 360 228 340 222 Z"

def mark(col, ring=True):
    g = f'<g transform="translate(-16 10)"><path d="{DUCK}" fill="{col}" fill-rule="evenodd"/><path d="{BILL}" fill="{col}"/></g>'
    r = f'<path d="{RING}" fill="none" stroke="{col}" stroke-width="{W}" stroke-linecap="round"/>' if ring else ""
    return r + g

def svg(col=BLUE, bg=None, size=512, scale=1.0, ring=True):
    """scale<1 shrinks the mark around the centre (adaptive-icon safe zone)."""
    b = f'<rect width="512" height="512" fill="{bg}"/>' if bg else ""
    t = f"translate(256 256) scale({scale}) translate(-256 -256)"
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 512 512">'
            f'{b}<g transform="{t}">{mark(col, ring)}</g></svg>')

if __name__ == "__main__":
    print(svg())
