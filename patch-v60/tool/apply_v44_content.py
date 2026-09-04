"""Apply approved v44 edits after build_next_letters.py; no network/generation."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT.parent / 'video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))

def write(path, data):
    (ROOT / path).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def duration(path):
    result = subprocess.run([str(FFMPEG), '-hide_banner', '-i', str(ROOT/path)], capture_output=True, text=True, encoding='utf-8', errors='replace').stderr
    match = re.search(r'Duration: (\d+):(\d+):([\d.]+)', result)
    if not match:
        raise ValueError(f'Missing/invalid MP3: {path}')
    h, m, s = map(float, match.groups())
    return round(h*3600+m*60+s, 2)

texts = read('tool/v44_narration.json')
assets = {key: f'assets/audio/jeem_v44/{key}.mp3' for key in texts}
durations = {key: duration(path) for key, path in assets.items()}

def update(value):
    if isinstance(value, str):
        for key, path in assets.items():
            if value == f'assets/audio/jeem/{key}.mp3':
                return path
        return value.replace('الجيم', 'الجَا')
    if isinstance(value, list):
        return [update(x) for x in value]
    if isinstance(value, dict):
        value = {k: update(v) for k, v in value.items()}
        if value.get('audio') in assets.values() and 'durationSec' in value:
            key = Path(value['audio']).stem
            value.update(male=texts[key], female=texts[key], durationSec=durations[key])
        return value
    return value

question_audio = {
    'alif': 'assets/audio/taa/prior_review_2.mp3',
    'baa': 'assets/audio/taa/prior_review_3.mp3',
    'taa': 'assets/audio/taa/assessment_1.mp3',
    'thaa': 'assets/audio/thaa/assessment_1.mp3',
    'jeem': assets['assessment_1'],
}
for letter in ['baa', 'taa', 'thaa', 'jeem', 'haa']:
    path = f'assets/content/lesson_{letter}.json'
    lesson = read(path)
    if letter == 'jeem':
        lesson = update(lesson)
        for scene in lesson['scenes']:
            if scene['type'] == 'guidedWriting':
                scene['data']['demoPassDurationMs'] = round(durations['writing_demo']*500)
            if scene['type'] == 'success':
                scene['lines'][0]['events'][-1]['atSec'] = max(0, durations['closing']-2.8)
    review = next(s for s in lesson['scenes'] if s['type'] == 'review')
    review['title'] = 'مراجعة قبلية'
    review['lines'] = [{
        'male': 'قوموا باختيار حرف الآ.', 'female': 'قوموا باختيار حرف الآ.',
        'audio': question_audio['alif'], 'durationSec': duration(question_audio['alif']),
    }]
    for q in review['data']['questions']:
        q['showPrompt'] = False
        q['audio'] = question_audio[q['reviewLessonId']]
    write(path, lesson)

manifest = {path: {'sha256': hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),
                  'durationSec': durations[key], 'text': texts[key]}
            for key, path in assets.items()}
write('AUDIO_V44_MANIFEST.json', manifest)
print(f'Applied v44: {len(manifest)} corrected clips; five audio-only reviews.')
