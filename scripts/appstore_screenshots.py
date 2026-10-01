#!/usr/bin/env python3
"""App Store screenshots: each raw simulator capture framed under a caption, at 1320 x 2868, the
6.9-inch iPhone size in Apple's screenshot specifications (read 2026-10-01), saved without an alpha
channel, which App Store Connect refuses.

Capture the raw screens first, on a simulator of your own (never `OpenCone demo`, which holds keys):
  xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 ...
  xcrun simctl launch --terminate-running-process <udid> AI.FascinAIting.OpenCone -OpenConeDemo -OpenConeDemoScreen <screen>
  xcrun simctl io <udid> screenshot --type=png RAW/<screen>.png

Then:  python3 scripts/appstore_screenshots.py RAW_DIR OUT_DIR

Captions say only what the screen shows. No price words: App Review rejected OpenManual 1.4 under
guideline 2.3.7 for a caption that said "free".
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1320, 2868
FONT = "/System/Library/Fonts/SFNS.ttf"
TOP, BOTTOM = (20, 128, 255), (6, 66, 196)  # the icon's blue, darkening downward

# Order is store order: the first three show in search results
SHOTS = [
    ("answer", "01-answer", "Ask your documents", "Answers cite the exact passages they came from"),
    ("scope", "02-scope", "Search one index or all of them", "Auto picks where to look for each question"),
    ("sources", "03-sources", "Every source, one tap away", "The passages behind each answer, with their scores"),
    ("documents", "04-documents", "Index files from your iPhone", "PDFs, text, Markdown, HTML, images and more"),
    ("document", "05-document", "Watch each file get indexed", "Read, split, embed and store, timed step by step"),
    ("settings-answers", "06-answer-settings", "Answers shaped by the model", "Length, detail, reasoning and web search for each one"),
    ("models", "07-models", "Choose the model", "Any model your OpenAI key can use"),
    ("endpoints", "08-endpoints", "Every API call in view", "Each OpenAI and Pinecone endpoint, its settings and status"),
]


def font(size, weight):
    face = ImageFont.truetype(FONT, size)
    try:
        face.set_variation_by_name(weight)
    except (OSError, ValueError):
        pass
    return face


def wrapped(draw, text, face, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=face) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def background():
    canvas = Image.new("RGB", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(canvas)
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        draw.line([(0, y), (WIDTH, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return canvas


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def compose(raw_path, headline, subhead):
    canvas = background()
    draw = ImageDraw.Draw(canvas)

    head_face, sub_face = font(92, "Bold"), font(50, "Regular")
    y = 150
    for line in wrapped(draw, headline, head_face, 1160):
        draw.text((WIDTH / 2, y), line, font=head_face, fill="white", anchor="ma")
        y += 108
    y += 18
    for line in wrapped(draw, subhead, sub_face, 1120):
        draw.text((WIDTH / 2, y), line, font=sub_face, fill=(222, 234, 255), anchor="ma")
        y += 64

    # The screen at 78%, in a thin black bezel, with a soft shadow; it starts below the caption
    scale = 0.78
    screen = Image.open(raw_path).convert("RGB")
    screen = screen.resize((round(screen.width * scale), round(screen.height * scale)), Image.LANCZOS)
    bezel, radius = 16, 140
    phone_w, phone_h = screen.width + 2 * bezel, screen.height + 2 * bezel
    left, top = (WIDTH - phone_w) // 2, max(y + 50, 560)

    shadow = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [left, top + 30, left + phone_w, top + 30 + phone_h], radius=radius + bezel, fill=110)
    canvas.paste((2, 28, 90), (0, 0), shadow.filter(ImageFilter.GaussianBlur(45)))

    canvas.paste((12, 12, 14), (left, top), rounded_mask((phone_w, phone_h), radius + bezel))
    canvas.paste(screen, (left + bezel, top + bezel), rounded_mask(screen.size, radius))
    return canvas


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    for screen, name, headline, subhead in SHOTS:
        image = compose(raw_dir / f"{screen}.png", headline, subhead)
        assert image.size == (WIDTH, HEIGHT) and image.mode == "RGB"
        image.save(out_dir / f"{name}.png", optimize=True)
        print(out_dir / f"{name}.png")


if __name__ == "__main__":
    main()
