"""Apply v46 flow fixes using verified local audio; no TTS requests here."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = ['alif', 'baa', 'taa', 'thaa', 'jeem', 'haa']
def read(path): return json.loads((ROOT / path).read_text(encoding='utf-8'))
def write(path, data): (ROOT / path).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def asset(key): return f'assets/audio/v46/{key}.mp3'

def apply():
    texts = read('tool/v46_narration.json')
    records = {r['key']: r for r in read('VOICEOVER_V46_GENERATIONS.json')}
    assert set(texts) == set(records)
    manifest = {}
    for key, text in texts.items():
        assert records[key]['prompt'] == text
        path = asset(key)
        payload = (ROOT/path).read_bytes()
        assert len(payload) > 1000
        manifest[path] = {'text': text, 'sha256': hashlib.sha256(payload).hexdigest(),
                         'durationSec': records[key]['durationSec']}
    def line(key):
        return {'male':texts[key], 'female':texts[key], 'audio':asset(key),
                'durationSec':records[key]['durationSec']}
    question = {'alif':'assets/audio/taa/prior_review_2.mp3',
                'baa':'assets/audio/taa/prior_review_3.mp3',
                'taa':'assets/audio/v45/taa_review_letter.mp3',
                'thaa':'assets/audio/thaa/assessment_1.mp3',
                'jeem':'assets/audio/jeem_v44/assessment_1.mp3',
                'haa':'assets/audio/haa/assessment_1.mp3'}
    for slug in IDS:
        lesson = read(f'assets/content/lesson_{slug}.json')
        scenes = {s['type']:s for s in lesson['scenes']}
        if 'review' in scenes:
            review = scenes['review']
            review['canSkip'] = False
            for q in review['data']['questions']:
                if q.get('kind') == 'word' and q.get('reviewLessonId') == 'thaa':
                    q['answerAudio'] = asset('thaa_example')
        if slug in ['thaa', 'jeem', 'haa']:
            scenes['pronunciation']['data']['successAudio'] = 'assets/audio/alif/pronounce_success.mp3'
        if slug == 'thaa':
            for index in [2, 4]:
                previous = scenes['explanation']['lines'][index]
                updated = line('thaa_example')
                if previous.get('events'):
                    updated['events'] = copy.deepcopy(previous['events'])
                    for event in updated['events']:
                        event['atSec'] = min(event['atSec'], records['thaa_example']['durationSec'] - .2)
                scenes['explanation']['lines'][index] = updated
        guided = scenes['guidedWriting']
        guided['data']['writing']['guidedAttempts'] = 1
        guided['lines'][0] = line(slug+'_writing_demo')
        guided['data']['demoPassDurationMs'] = round(records[slug+'_writing_demo']['durationSec']*1000)+450
        # Repeat is explicit; it uses the existing practice prompt, not "again".
        guided['data']['againAudio'] = guided['lines'][-1]['audio']
        scenes['freeWriting']['data']['successAudio'] = asset('free_praise')
        scenes['freeWriting']['data']['successText'] = 'ممتاز! أحسنتم كتابة الحرف'
        assessment = scenes.get('multipleChoice', scenes.get('assessment'))
        assessment['lines'] = [line('assessment_intro')]
        assessment['data']['questionAfterIntro'] = True
        assessment['data']['questions'][0]['audio'] = question[slug]
        if slug in ['alif', 'baa', 'taa']:
            assessment['data']['secondAudio'] = f'assets/audio/v45/{slug}_review_word.mp3'
        write(f'assets/content/lesson_{slug}.json', lesson)
    write('AUDIO_V46_MANIFEST.json', manifest)
    print('v46: six lessons, nine corrected recordings, one guided attempt, no review skip.')

if __name__ == '__main__': apply()
