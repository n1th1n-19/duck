"""Duck logo "Glide": a rubber duck gliding on two wake lines. One source for every asset."""
BLUE = "#1E6FD9"

BODY = ("M118 232 Q116 214 134 220 C168 236 212 256 262 256 C322 256 370 262 394 290 "
        "C412 312 404 342 380 358 C350 378 310 386 262 386 C190 386 138 362 126 320 C118 292 116 262 118 232 Z")
# head circle with the eye as an evenodd hole, so the eye stays transparent
HEAD = ("M384 206 A64 64 0 1 0 256 206 A64 64 0 1 0 384 206 Z "
        "M349 198 A13 13 0 1 0 323 198 A13 13 0 1 0 349 198 Z")
BILL = "M372 198 C394 188 424 192 436 208 C424 226 396 232 374 224 Z"
WAKE = "M84 426 H196 M140 462 H236"

def mark(col):
    # translate centres the mark's bounds (x 84..436, y 142..475) in the 512 box
    return (f'<g transform="translate(-4 -52)"><path d="{BODY}" fill="{col}"/>'
            f'<path d="{HEAD}" fill="{col}" fill-rule="evenodd"/><path d="{BILL}" fill="{col}"/>'
            f'<path d="{WAKE}" fill="none" stroke="{col}" stroke-width="26" stroke-linecap="round"/></g>')

def svg(col=BLUE, bg=None, size=512, scale=1.0):
    """scale<1 shrinks the mark around the centre (adaptive-icon safe zone)."""
    b = f'<rect width="512" height="512" fill="{bg}"/>' if bg else ""
    t = f"translate(256 256) scale({scale}) translate(-256 -256)"
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 512 512">'
            f'{b}<g transform="{t}">{mark(col)}</g></svg>')

if __name__ == "__main__":
    print(svg())
