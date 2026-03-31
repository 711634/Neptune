#!/usr/bin/env python3
"""Generate Clonk app icon - pixel art coding pet on dark gradient background."""

from PIL import Image, ImageDraw, ImageFilter
import math
import os

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))

def create_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = size

    # --- Background: rounded rect with dark gradient ---
    corner_r = int(s * 0.22)
    mask = Image.new("L", (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=corner_r, fill=255)

    bg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)

    # Gradient: deep navy at top → near-black at bottom
    top_color = (12, 10, 30, 255)
    bot_color = (4, 4, 16, 255)
    for y in range(s):
        t = y / (s - 1)
        col = lerp_color(top_color, bot_color, t)
        bg_draw.line([(0, y), (s - 1, y)], fill=col)

    # Subtle inner glow / vignette tint (purple at top-center)
    for y in range(s // 2):
        for x in range(s // 4, 3 * s // 4):
            dx = (x - s / 2) / (s / 2)
            dy = y / (s / 2)
            dist = math.sqrt(dx * dx + dy * dy)
            glow = max(0, 1 - dist * 1.4) * 0.18
            px = bg.getpixel((x, y))
            r = min(255, int(px[0] + 30 * glow))
            gb = min(255, int(px[1] + 5 * glow))
            b = min(255, int(px[2] + 60 * glow))
            bg.putpixel((x, y), (r, gb, b, 255))

    bg.putalpha(mask)
    img.paste(bg, (0, 0), bg)

    # --- Pixel pet ---
    # Scale pixel grid to icon size. Base grid is 12x10 in a 54px canvas.
    # We'll draw in a scaled coordinate space.
    canvas_size = s * 0.62  # pet occupies 62% of icon
    px = canvas_size / 12.0
    # Center the pet
    ox = s * 0.5 - canvas_size * 0.5  # left offset
    oy = s * 0.5 - canvas_size * 0.52  # slightly above center

    # Colors: vibrant green (coding pet theme)
    body_color   = (100, 220, 140, 255)   # mint green body
    dark_color   = (40,  120,  70, 255)   # dark green accents
    accent_color = (180, 255, 160, 255)   # bright highlight
    bg_dark      = (10,  10,  25, 255)    # dark bg for eyes
    white_hl     = (255, 255, 255, 200)   # eye highlight

    def fill_pixel(x, y, color, radius_frac=0.12):
        rx = ox + x * px
        ry = oy + y * px
        r_val = max(1, int(px * radius_frac))
        x0, y0 = int(rx), int(ry)
        x1, y1 = int(rx + max(1, px - 1)), int(ry + max(1, px - 1))
        if x1 <= x0:
            x1 = x0 + 1
        if y1 <= y0:
            y1 = y0 + 1
        draw.rounded_rectangle([x0, y0, x1, y1], radius=r_val, fill=color)

    # Pixel body map — same layout as in-app sprite
    for y in range(10):
        for x in range(12):
            xoff = x - 5.5
            is_ear = (x == 1 and y == 1) or (x == 10 and y == 1)
            is_top = y == 2 and abs(xoff) <= 3.5
            is_mid = y in (3, 4, 5) and abs(xoff) <= 4.5
            is_bot = y == 6 and abs(xoff) <= 3.5
            is_feet = y == 7 and (x in (2, 3, 8, 9))

            if is_ear:
                fill_pixel(x, y, dark_color)
            elif is_top or is_mid or is_bot:
                fill_pixel(x, y, body_color)
            elif is_feet:
                col = dark_color if x in (2, 9) else body_color
                fill_pixel(x, y, col)

    # Eyes (coding — focused squint)
    cx = ox + 5.5 * px  # center x in pixel space
    cy = oy + 3.8 * px  # eye y row

    eye_w = px * 0.85
    eye_h = px * 0.45  # squint
    gap   = 1.4 * px

    lx = cx - gap - eye_w
    rx_ = cx + gap * 0.18
    draw.ellipse([lx, cy, lx + eye_w, cy + eye_h], fill=bg_dark)
    draw.ellipse([rx_, cy, rx_ + eye_w, cy + eye_h], fill=bg_dark)

    # Eye highlights
    hl_size = eye_w * 0.3
    draw.ellipse([lx + 2, cy + 1, lx + 2 + hl_size, cy + 1 + hl_size], fill=white_hl)
    draw.ellipse([rx_ + 2, cy + 1, rx_ + 2 + hl_size, cy + 1 + hl_size], fill=white_hl)

    # Smile
    sm_y = oy + 7.0 * px
    sm_l = cx - 1.2 * px
    sm_r = cx + 1.2 * px
    points = []
    for i in range(20):
        t = i / 19.0
        x_pt = sm_l + (sm_r - sm_l) * t
        y_pt = sm_y + math.sin(t * math.pi) * px * 0.6
        points.append((x_pt, y_pt))
    if len(points) > 1:
        for i in range(len(points) - 1):
            lw = max(1, int(px * 0.35))
            draw.line([points[i], points[i+1]], fill=dark_color, width=lw)

    # Sparkle stars (top-right of pet)
    star_color = (255, 230, 50, 255)
    for i, (sx, sy, sr) in enumerate([
        (0.70, 0.20, 0.022),
        (0.80, 0.12, 0.015),
        (0.65, 0.10, 0.012),
    ]):
        sp = (sx * s, sy * s)
        r = sr * s
        # draw 4-point star
        for ang in [0, 45, 90, 135]:
            rad = math.radians(ang)
            x1 = sp[0] + math.cos(rad) * r * 2.2
            y1 = sp[1] + math.sin(rad) * r * 2.2
            x2 = sp[0] - math.cos(rad) * r * 2.2
            y2 = sp[1] - math.sin(rad) * r * 2.2
            lw = max(1, int(r * 0.6))
            draw.line([(x1, y1), (x2, y2)], fill=star_color, width=lw)

    # --- Subtle border glow ---
    border_img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border_img)
    border_draw.rounded_rectangle(
        [1, 1, s - 2, s - 2],
        radius=corner_r - 1,
        outline=(100, 220, 140, 60),
        width=max(1, s // 128)
    )
    img = Image.alpha_composite(img, border_img)

    return img


def main():
    icon_dir = "/Users/misbah/Clonk/Clonk/Resources/Assets.xcassets/AppIcon.appiconset"
    sizes = [16, 32, 64, 128, 256, 512, 1024]

    images = {}
    for size in sizes:
        images[size] = create_icon(size)
        print(f"Generated {size}x{size}")

    # Save individual sizes
    name_map = {
        16:   "icon_16x16.png",
        32:   "icon_32x32.png",
        64:   "icon_64x64.png",
        128:  "icon_128x128.png",
        256:  "icon_256x256.png",
        512:  "icon_512x512.png",
        1024: "icon_512x512@2x.png",
    }
    for size, fname in name_map.items():
        path = os.path.join(icon_dir, fname)
        images[size].save(path, "PNG")
        print(f"Saved {path}")

    # Also save 16@2x (32px as 16@2x) and 32@2x (64px as 32@2x)
    images[32].save(os.path.join(icon_dir, "icon_16x16@2x.png"), "PNG")
    images[64].save(os.path.join(icon_dir, "icon_32x32@2x.png"), "PNG")
    images[256].save(os.path.join(icon_dir, "icon_128x128@2x.png"), "PNG")
    images[512].save(os.path.join(icon_dir, "icon_256x256@2x.png"), "PNG")
    print("Done!")


if __name__ == "__main__":
    main()
