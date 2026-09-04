"""Use the speaking portion of the user's clip, omitting its silent lead/tail.
No character pixels are repainted; retain the original animation unchanged.
"""
from pathlib import Path
from PIL import Image

folder = Path(__file__).resolve().parents[1] / 'assets/character/saleh_video'
source = Image.open(folder / 'saleh_talking_alpha.webp')
frames, durations = [], []
for index in range(12, 55):
    source.seek(index)
    frame = source.convert('RGBA')
    frames.append(frame)
    durations.append(source.info.get('duration', 67))
target = folder / 'saleh_talking_speech_alpha.webp'
frames[0].save(target, save_all=True, append_images=frames[1:],
    duration=durations, loop=0, lossless=True, method=4, exact=True)
frames[0].save(folder / 'saleh_talking_speech_alpha_poster.png')
print(f'{target}: {len(frames)} frames, {sum(durations)}ms')
