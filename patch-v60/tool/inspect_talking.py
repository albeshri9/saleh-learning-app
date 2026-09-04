"""Diagnostic contact sheet of existing Talking frames; does not edit assets."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'assets/character/saleh_video/saleh_talking_alpha.webp')
sheet = Image.new('RGB', (960, 400), '#fff8ed')
for column, frame in enumerate([0, 8, 16, 24, 40, 60]):
    source.seek(frame)
    head = source.convert('RGBA').crop((130, 0, 350, 260))
    head.thumbnail((160, 350))
    sheet.paste(head, (column * 160, 20), head)
    ImageDraw.Draw(sheet).text((column * 160 + 10, 5), f'Frame {frame}', fill='black')
target = root / 'test/goldens/talking-frames-v36.png'
target.parent.mkdir(parents=True, exist_ok=True)
sheet.save(target)
print(target)
