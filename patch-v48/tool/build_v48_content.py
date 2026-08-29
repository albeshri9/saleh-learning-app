"""Build the Khaa lesson and first seven-letter mastery checkpoint."""
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT.parent / 'video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
NARRATION = json.loads((ROOT / 'tool/v48_narration.json').read_text(encoding='utf-8'))

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))

def write(path, data):
    (ROOT / path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def duration(path):
    probe = subprocess.run([str(FFMPEG), '-hide_banner', '-i', str(ROOT / path)],
        capture_output=True, text=True, encoding='utf-8', errors='replace').stderr
    match = re.search(r'Duration: (\d+):(\d+):([\d.]+)', probe)
    if not match:
        raise ValueError(f'Invalid audio: {path}')
    hours, minutes, seconds = map(float, match.groups())
    return round(hours * 3600 + minutes * 60 + seconds, 2)

def audio(key):
    folder = 'checkpoint_1' if key.startswith('checkpoint_') else 'khaa'
    return f'assets/audio/{folder}/{key}.mp3'

def line(key, events=None):
    result = {'male': NARRATION[key], 'female': NARRATION[key],
              'audio': audio(key), 'durationSec': duration(audio(key))}
    if events:
        result['events'] = copy.deepcopy(events)
    return result

lesson = copy.deepcopy(read('assets/content/lesson_haa.json'))
lesson.update(id='khaa', title='درس حرف خَ')
scenes = {scene['id']: scene for scene in lesson['scenes']}
scenes['welcome_1']['lines'] = [line('welcome', scenes['welcome_1']['lines'][0].get('events'))]
scenes['nasheed_1']['lines'] = [line('nasheed_intro')]
scenes['nasheed_1']['data']['label'] = 'أنشودة حرف خَ'
scenes['explain_1']['lines'] = [
    line(f'explain_{index}', old.get('events'))
    for index, old in enumerate(scenes['explain_1']['lines'], 1)
]
scenes['explain_1']['data'] = {
    'letter': 'خَ', 'letterName': 'الخَا', 'letterAudio': audio('explain_2'),
    'example': {'word': 'خَرُوف',
                'imageAsset': 'assets/images/assessment/sheep_v48.png',
                'highlightPrefix': 'خَ'}
}
scenes['pronounce_1']['lines'] = [line('pronounce_intro')]
scenes['pronounce_1']['data'].update(
    letter='خَ', spokenLetter='خَا', expected='خَا',
    retryAudio=audio('pronounce_retry'), letterAudio=audio('explain_2'))
scenes['write_guided_1']['lines'] = [line('writing_demo'), line('writing_try')]
scenes['write_guided_1']['data'].update(
    letter='خَ', lessonId='khaa', traceTemplateId='khaa_fatha_pdf_v1',
    againAudio=audio('writing_try'),
    demoPassDurationMs=round(duration(audio('writing_demo')) * 1000))
scenes['write_free_1']['lines'] = [line('free_intro')]
scenes['write_free_1']['data'].update(
    letter='خَ', lessonId='khaa', traceTemplateId='khaa_fatha_pdf_v1')
scenes['assessment_1']['data'].update(
    secondAudio=audio('assessment_2'), questionAfterIntro=True,
    questions=[
        {'prompt': 'اضغط على حرف خَ', 'showPrompt': False,
         'options': ['خَ', 'جَ', 'حَ', 'ثَ'], 'correctIndex': 0,
         'audio': audio('assessment_1')},
        {'prompt': 'ما الكلمة التي تبدأ بحرف خَ؟', 'showPrompt': False,
         'options': ['خَرُوف', 'جَمَل', 'حَبْل'],
         'optionImages': ['assets/images/assessment/sheep_v48.png',
                          'assets/images/assessment/camel_v43.png',
                          'assets/images/assessment/rope_v43.png'],
         'correctIndex': 0, 'audio': audio('assessment_2')}
    ])
closing_events = scenes['success_1']['lines'][0].get('events')
scenes['success_1']['lines'] = [line('closing', closing_events)]

ids = ['alif', 'baa', 'taa', 'thaa', 'jeem', 'haa']
letters = {'alif': 'أَ', 'baa': 'بَ', 'taa': 'تَ', 'thaa': 'ثَ',
           'jeem': 'جَ', 'haa': 'حَ', 'khaa': 'خَ'}
letter_audio = {
    'alif': 'assets/audio/taa/prior_review_2.mp3',
    'baa': 'assets/audio/taa/prior_review_3.mp3',
    'taa': 'assets/audio/v45/taa_review_letter.mp3',
    'thaa': 'assets/audio/thaa/assessment_1.mp3',
    'jeem': 'assets/audio/jeem_v44/assessment_1.mp3',
    'haa': 'assets/audio/haa/assessment_1.mp3',
    'khaa': audio('assessment_1'),
}
word_audio = {
    'alif': 'assets/audio/v45/alif_review_word.mp3',
    'baa': 'assets/audio/v45/baa_review_word.mp3',
    'taa': 'assets/audio/v45/taa_review_word.mp3',
    'thaa': 'assets/audio/thaa/assessment_2.mp3',
    'jeem': 'assets/audio/jeem_v44/assessment_2.mp3',
    'haa': 'assets/audio/haa/assessment_2.mp3',
    'khaa': audio('assessment_2'),
}
review = scenes['prior_review_1']
review['data']['priorLessonIds'] = ids
review['data']['questions'] = []
packs_by_id = {p['id']: p for p in read('assets/content/lesson_packs.json')['packs']}
for item in ids:
    choices = [letters[item]] + [value for value in letters.values() if value != letters[item]][:3]
    review['data']['questions'].append({
        'kind': 'letter', 'reviewLessonId': item, 'showPrompt': False,
        'prompt': f'أين حرف {letters[item]}؟', 'options': choices,
        'correctIndex': 0, 'audio': letter_audio[item],
        'successAudio': 'assets/audio/taa/assessment_success.mp3',
        'retryAudio': 'assets/audio/taa/assessment_retry.mp3'})
for item in ids:
    source = read(packs_by_id[item]['lessonAsset'])
    assessment = next(s for s in source['scenes'] if s['id'] == 'assessment_1')
    question = copy.deepcopy(assessment['data']['questions'][1])
    question.update(kind='word', reviewLessonId=item, showPrompt=False,
                    audio=word_audio[item],
                    successAudio='assets/audio/taa/assessment_success.mp3',
                    retryAudio='assets/audio/taa/assessment_retry.mp3')
    review['data']['questions'].append(question)
write('assets/content/lesson_khaa.json', lesson)

letter_rows = [
    {'id': 'alif', 'letter': 'أَ', 'word': 'أَسَد', 'image': 'assets/images/assessment/alif_lion.png'},
    {'id': 'baa', 'letter': 'بَ', 'word': 'بَطَّة', 'image': 'assets/images/assessment/duck.png'},
    {'id': 'taa', 'letter': 'تَ', 'word': 'تَاج', 'image': 'assets/images/assessment/crown_v41.png'},
    {'id': 'thaa', 'letter': 'ثَ', 'word': 'ثَعْلَب', 'image': 'assets/images/assessment/fox.png'},
    {'id': 'jeem', 'letter': 'جَ', 'word': 'جَمَل', 'image': 'assets/images/assessment/camel_v43.png'},
    {'id': 'haa', 'letter': 'حَ', 'word': 'حَبْل', 'image': 'assets/images/assessment/rope_v43.png'},
    {'id': 'khaa', 'letter': 'خَ', 'word': 'خَرُوف', 'image': 'assets/images/assessment/sheep_v48.png'},
]
for row in letter_rows:
    row['letterAudio'] = letter_audio[row['id']]
    row['wordAudio'] = word_audio[row['id']]

def pairs(ids):
    by_id = {row['id']: row for row in letter_rows}
    return [{'letter': by_id[item]['letter'], 'word': by_id[item]['word'],
             'image': by_id[item]['image']} for item in ids]

tasks = [
    {'id':'recognize_taa','type':'choice','letter':'تَ','prompt':'اختر حرف تَ',
     'options':['تَ','بَ','ثَ'],'correctIndex':0,'audio':letter_audio['taa']},
    {'id':'recognize_khaa','type':'choice','letter':'خَ','prompt':'اختر حرف خَ',
     'options':['خَ','حَ','جَ'],'correctIndex':0,'audio':letter_audio['khaa']},
    {'id':'picture_alif','type':'image','letter':'أَ','prompt':'اختر الصورة التي تبدأ بحرف أَ',
     'options':['أَسَد','بَطَّة','ثَعْلَب'],
     'optionImages':[letter_rows[0]['image'],letter_rows[1]['image'],letter_rows[3]['image']],
     'correctIndex':0,'audio':word_audio['alif']},
    {'id':'picture_haa','type':'image','letter':'حَ','prompt':'اختر الصورة التي تبدأ بحرف حَ',
     'options':['حَبْل','جَمَل','خَرُوف'],
     'optionImages':[letter_rows[5]['image'],letter_rows[4]['image'],letter_rows[6]['image']],
     'correctIndex':0,'audio':word_audio['haa']},
    {'id':'match_first','type':'match','letter':'أَ','prompt':'صِل كل حرف بالصورة المناسبة',
     'pairs':pairs(['alif','baa','taa','thaa'])},
    {'id':'match_shapes','type':'match','letter':'جَ','prompt':'صِل كل حرف بالصورة المناسبة',
     'pairs':pairs(['jeem','haa','khaa'])},
    {'id':'listen_baa','type':'listen','letter':'بَ','prompt':'استمع واختر الحرف الصحيح',
     'options':['بَ','تَ','ثَ'],'correctIndex':0,'audio':letter_audio['baa']},
    {'id':'listen_jeem','type':'listen','letter':'جَ','prompt':'استمع واختر الحرف الصحيح',
     'options':['جَ','حَ','خَ'],'correctIndex':0,'audio':letter_audio['jeem']},
    {'id':'pronounce_thaa','type':'pronounce','letter':'ثَ','prompt':'انطق صوت الحرف ثَا',
     'expected':'ثَا','audio':'assets/audio/thaa/pronounce_intro.mp3'},
    {'id':'pronounce_khaa','type':'pronounce','letter':'خَ','prompt':'انطق صوت الحرف خَا',
     'expected':'خَا','audio':audio('pronounce_intro')},
    {'id':'guided_jeem','type':'guided','letter':'جَ','prompt':'اكتب جَ فوق المسار',
     'traceTemplateId':'jeem_fatha_pdf_v1'},
    {'id':'guided_khaa','type':'guided','letter':'خَ','prompt':'اكتب خَ فوق المسار',
     'traceTemplateId':'khaa_fatha_pdf_v1'},
    {'id':'free_taa','type':'free','letter':'تَ','prompt':'اكتب تَ كتابة حرة',
     'traceTemplateId':'taa_fatha_pdf_v1'},
    {'id':'free_haa','type':'free','letter':'حَ','prompt':'اكتب حَ كتابة حرة',
     'traceTemplateId':'haa_fatha_pdf_v1'},
    {'id':'similar_thaa','type':'similar','letter':'ثَ','prompt':'أي حرف له ثلاث نقاط؟',
     'options':['ثَ','تَ','بَ'],'correctIndex':0,'audio':letter_audio['thaa']},
    {'id':'similar_khaa','type':'similar','letter':'خَ','prompt':'اختر خَ من الحروف المتشابهة',
     'options':['خَ','حَ','جَ'],'correctIndex':0,'audio':letter_audio['khaa']},
]
checkpoint = {
    'id':'checkpoint_group_1', 'title':'الاختبار المرحلي للمجموعة الأولى',
    'mastery':{'minScore':.85,'requiredSceneIds':['checkpoint_1']},
    'scenes':[
        {'id':'checkpoint_1','type':'checkpoint','title':'الاختبار المرحلي',
         'canSkip':False,'lines':[line('checkpoint_intro')],
         'data':{'tasks':tasks,'letters':letter_rows,
                 'successAudio':'assets/audio/taa/assessment_success.mp3',
                 'wrongAudio':audio('checkpoint_wrong')}},
        {'id':'success_1','type':'success','title':'أحسنت','canSkip':False,
         'lines':[{'male':'ممتاز! أحسنتم، إجابة صحيحة.',
                   'female':'ممتاز! أحسنتم، إجابة صحيحة.',
                   'audio':'assets/audio/taa/assessment_success.mp3',
                   'durationSec':duration('assets/audio/taa/assessment_success.mp3')}],
         'data':{'stars':3}}
    ]
}
write('assets/content/lesson_checkpoint_group_1.json', checkpoint)

packs = read('assets/content/lesson_packs.json')
packs['packs'] = [p for p in packs['packs'] if p['id'] not in {'khaa','checkpoint_group_1'}]
checklist = packs['packs'][0]['reviewChecklist']
packs['packs'].extend([
    {'id':'khaa','version':1,'title':'حرف الخاء','letter':'خَ',
     'stageId':'letters_fatha','priorLessonIds':ids,'status':'available',
     'lessonAsset':'assets/content/lesson_khaa.json','audioFolder':'assets/audio/khaa/',
     'traceTemplateIds':['khaa_fatha_pdf_v1'],
     'exampleImages':['assets/images/assessment/sheep_v48.png'],
     'reviewChecklist':checklist},
    {'id':'checkpoint_group_1','version':1,'title':'الاختبار المرحلي',
     'kind':'checkpoint',
     'stageId':'letters_fatha','priorLessonIds':ids+['khaa'],'status':'available',
     'lessonAsset':'assets/content/lesson_checkpoint_group_1.json',
     'audioFolder':'assets/audio/checkpoint_1/',
     'traceTemplateIds':['taa_fatha_pdf_v1','jeem_fatha_pdf_v1',
                         'haa_fatha_pdf_v1','khaa_fatha_pdf_v1'],
     'exampleImages':[row['image'] for row in letter_rows],
     'reviewChecklist':checklist},
])
write('assets/content/lesson_packs.json', packs)

programs = read('assets/content/programs.json')
lessons = programs[0]['stages'][0]['levels'][0]['lessons']
lessons[:] = [item for item in lessons
              if item['lessonId'] not in {'khaa','checkpoint_group_1'}]
lessons.extend([
    {'lessonId':'khaa','title':'حرف الخاء','subtitle':'خَ — خَرُوف','letter':'خَ'},
    {'lessonId':'checkpoint_group_1','title':'الاختبار المرحلي',
     'subtitle':'إتقان حروف المجموعة الأولى'},
])
write('assets/content/programs.json', programs)

manifest = {}
for key, text in NARRATION.items():
    path = audio(key)
    manifest[path] = {'sha256': hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),
                      'durationSec': duration(path), 'text': text}
write('AUDIO_V48_MANIFEST.json', manifest)
print('v48 content: Khaa lesson, 16-activity checkpoint, 18 new recordings.')
