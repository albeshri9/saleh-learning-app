"""Build group-two fatha lessons and the second track-aware checkpoint."""
import copy
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT.parent / 'video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))

def write(path, data):
    (ROOT / path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def duration(path):
    result = subprocess.run([str(FFMPEG), '-hide_banner', '-i', str(ROOT / path)],
                            capture_output=True, text=True, encoding='utf-8', errors='replace').stderr
    match = re.search(r'Duration: (\d+):(\d+):([\d.]+)', result)
    if not match:
        raise ValueError(f'Invalid audio: {path}')
    h, m, s = map(float, match.groups())
    return round(h * 3600 + m * 60 + s, 2)

NEW = [
    dict(id='dal', name='الدال', article='الدَا', assessment='الدَّا',
         spoken='دَا', letter='دَ', word='دَجَاجَة',
         image='chicken_v54.png', template='dal_fatha_pdf_v1'),
    dict(id='dhal', name='الذال', article='الذَا', assessment='الذَّا',
         spoken='ذَا', letter='ذَ', word='ذَيْل',
         image='tail_v54.png', template='dhal_fatha_pdf_v1'),
    dict(id='raa', name='الراء', article='الرَا', assessment='الرَّا',
         spoken='رَا', letter='رَ', word='رَجُل',
         image='man_v54.png', template='raa_fatha_pdf_v1'),
    dict(id='zay', name='الزاي', article='الزَا', assessment='الزَّا',
         spoken='زَا', letter='زَ', word='زَرَافَة',
         image='giraffe_v54.png', template='zay_fatha_pdf_v1'),
    dict(id='seen', name='السين', article='السَا', assessment='السَّا',
         spoken='سَا', letter='سَ', word='سَاعَة',
         image='clock_v54.png', template='seen_fatha_pdf_v1'),
]
OLD_IDS = ['alif', 'baa', 'taa', 'thaa', 'jeem', 'haa', 'khaa']
ALL = OLD_IDS + [item['id'] for item in NEW]

OLD_META = {
    'alif': ('أَ', 'أَسَد', 'assets/images/assessment/alif_lion.png',
             'assets/audio/taa/prior_review_2.mp3', 'assets/audio/v45/alif_review_word.mp3'),
    'baa': ('بَ', 'بَطَّة', 'assets/images/assessment/duck.png',
            'assets/audio/taa/prior_review_3.mp3', 'assets/audio/v45/baa_review_word.mp3'),
    'taa': ('تَ', 'تَاج', 'assets/images/assessment/crown_v41.png',
            'assets/audio/v45/taa_review_letter.mp3', 'assets/audio/v45/taa_review_word.mp3'),
    'thaa': ('ثَ', 'ثَعْلَب', 'assets/images/assessment/fox.png',
             'assets/audio/thaa/assessment_1.mp3', 'assets/audio/thaa/assessment_2.mp3'),
    'jeem': ('جَ', 'جَمَل', 'assets/images/assessment/camel_v50.png',
             'assets/audio/jeem_v44/assessment_1.mp3', 'assets/audio/jeem_v44/assessment_2.mp3'),
    'haa': ('حَ', 'حَبْل', 'assets/images/assessment/rope_v50.png',
            'assets/audio/haa/assessment_1.mp3', 'assets/audio/haa/assessment_2.mp3'),
    'khaa': ('خَ', 'خَرُوف', 'assets/images/assessment/sheep_v48.png',
             'assets/audio/khaa/assessment_1.mp3', 'assets/audio/khaa/assessment_2.mp3'),
}
META = dict(OLD_META)
ASSESSMENT_NAMES = {}
for item in NEW:
    folder = f"assets/audio/{item['id']}"
    META[item['id']] = (item['letter'], item['word'],
                        f"assets/images/assessment/{item['image']}",
                        f'{folder}/assessment_letter.mp3',
                        f'{folder}/assessment_word.mp3')
    ASSESSMENT_NAMES[item['id']] = item['assessment']

def audio(item, key):
    return f"assets/audio/{item['id']}/{key}.mp3"

def line(item, key, text, events=None):
    path = audio(item, key)
    result = {'male': text, 'female': text, 'audio': path,
              'durationSec': duration(path)}
    if events:
        result['events'] = copy.deepcopy(events)
    return result

base = read('assets/content/lesson_khaa.json')
packs = read('assets/content/lesson_packs.json')
checklist = packs['packs'][0]['reviewChecklist']
packs['packs'] = [p for p in packs['packs']
                  if p['id'] not in {x['id'] for x in NEW} | {'checkpoint_group_2'}]

for position, item in enumerate(NEW):
    prior = ALL[:len(OLD_IDS) + position]
    lesson = copy.deepcopy(base)
    lesson.update(id=item['id'], title=f"درس حرف {item['article']}")
    scenes = {scene['id']: scene for scene in lesson['scenes']}
    old_events = scenes['welcome_1']['lines'][0].get('events')
    welcome = f"مرحبًا يا أصدقائي، كيف حالكم اليوم؟ سوف نتعلم اليوم حرفًا جديدًا، حرف {item['article']}. هيا بنا."
    scenes['welcome_1']['lines'] = [line(item, 'welcome', welcome, old_events)]
    nasheed = f"الآن نستمع نشيد حرف {item['article']}."
    scenes['nasheed_1']['lines'] = [line(item, 'nasheed_intro', nasheed)]
    scenes['nasheed_1']['data']['label'] = f"أنشودة حرف {item['article']}"
    explain = f"انظروا يا أصدقائي إلى حرف {item['article']}. {item['spoken']}، {item['word']}. {item['spoken']}، {item['word']}. رددوا معي: {item['spoken']}، {item['word']}."
    explain_events = scenes['explain_1']['lines'][0].get('events')
    scenes['explain_1']['lines'] = [line(item, 'explain', explain, explain_events)]
    scenes['explain_1']['data'] = {
        'letter': item['letter'], 'letterName': item['spoken'],
        'letterAudio': audio(item, 'explain'),
        'example': {'word': item['word'],
                    'imageAsset': f"assets/images/assessment/{item['image']}",
                    'highlightPrefix': item['letter']}}
    pronounce = f"هيا يا أصدقائي، سأستمع إلى نطقكم. {item['spoken']}، {item['spoken']}. اضغطوا على زر المايك وانطقوا الحرف."
    scenes['pronounce_1']['lines'] = [line(item, 'pronounce_intro', pronounce)]
    scenes['pronounce_1']['data'].update(
        letter=item['letter'], spokenLetter=item['spoken'], expected=item['spoken'],
        retryAudio='assets/audio/checkpoint_1/retry_only_v51.mp3',
        letterAudio=audio(item, 'explain'))
    shape = {
        'dal': 'نبدأ من أعلى اليمين، ونسير بمنحنى هادئ نحو اليسار حتى نكمل جسم الحرف.',
        'dhal': 'نبدأ من أعلى اليمين، ونسير بمنحنى هادئ نحو اليسار حتى نكمل جسم الحرف، ثم نضع نقطة فوقه.',
        'raa': 'نبدأ من أعلى اليمين، ثم ننزل بمنحنى هادئ إلى أسفل اليسار.',
        'zay': 'نبدأ من أعلى اليمين، ثم ننزل بمنحنى هادئ إلى أسفل اليسار، ثم نضع نقطة فوقه.',
        'seen': 'نبدأ من اليمين، ونرسم أسنان الحرف الصغيرة، ثم نكمل الانحناءة الطويلة إلى اليسار.',
    }[item['id']]
    demo = f"انظروا كيف نكتب حرف {item['article']}. {shape}"
    attempt = f"هيا يا أصدقائي، اكتبوا حرف {item['article']}. ضعوا إصبعكم على النقطة الخضراء، واتبعوا المسار حتى النهاية."
    scenes['write_guided_1']['lines'] = [line(item, 'writing_demo', demo),
                                         line(item, 'writing_try', attempt)]
    scenes['write_guided_1']['canSkip'] = False
    scenes['write_guided_1']['data'].update(
        letter=item['letter'], lessonId=item['id'], traceTemplateId=item['template'],
        againAudio=audio(item, 'writing_try'),
        demoPassDurationMs=round(duration(audio(item, 'writing_demo')) * 1000))
    free = f"هيا يا أصدقائي، اكتبوا حرف {item['article']} كتابة حرة الآن."
    scenes['write_free_1']['lines'] = [line(item, 'free_intro', free)]
    scenes['write_free_1']['canSkip'] = False
    scenes['write_free_1']['data'].update(
        letter=item['letter'], lessonId=item['id'], traceTemplateId=item['template'])
    letter_q = f"أين حرف {item['assessment']}؟ اضغطوا على حرف {item['assessment']}."
    word_q = f"أين الصورة التي تبدأ بحرف {item['assessment']}؟ اختاروا الصورة الصحيحة."
    distractors = [META[x] for x in prior[-3:]]
    scenes['assessment_1']['data'].update(
        secondAudio=audio(item, 'assessment_word'), questionAfterIntro=True,
        questions=[
            {'prompt': f"اضغط على حرف {item['assessment']}", 'showPrompt': False,
             'options': [item['letter']] + [x[0] for x in distractors],
             'correctIndex': 0, 'audio': audio(item, 'assessment_letter')},
            {'prompt': f"ما الكلمة التي تبدأ بحرف {item['assessment']}؟", 'showPrompt': False,
             'options': [item['word']] + [x[1] for x in distractors[:2]],
             'optionImages': [f"assets/images/assessment/{item['image']}"] +
                             [x[2] for x in distractors[:2]],
             'correctIndex': 0, 'audio': audio(item, 'assessment_word')}])
    closing = f"أحسنتم يا أبطال. لقد تعلمنا اليوم حرف {item['article']}. {item['spoken']}، {item['word']}. إلى اللقاء يا أصدقائي."
    scenes['success_1']['lines'] = [line(item, 'closing', closing,
                                             scenes['success_1']['lines'][0].get('events'))]

    # Six cumulative questions: three distinct letters and three distinct words.
    selected = prior[-6:]
    review = scenes['prior_review_1']
    review['data']['priorLessonIds'] = prior
    review['data']['questions'] = []
    for idx, previous in enumerate(selected):
        meta = META[previous]
        alternatives = [META[x] for x in prior if x != previous][:3]
        if idx < 3:
            sentence_letter = ASSESSMENT_NAMES.get(previous, meta[0])
            question = {'kind': 'letter', 'reviewLessonId': previous,
                        'showPrompt': False, 'prompt': f"أين حرف {sentence_letter}؟",
                        'options': [meta[0]] + [x[0] for x in alternatives],
                        'correctIndex': 0, 'audio': meta[3]}
        else:
            sentence_letter = ASSESSMENT_NAMES.get(previous, meta[0])
            question = {'kind': 'word', 'reviewLessonId': previous,
                        'showPrompt': False,
                        'prompt': f"أين الصورة التي تبدأ بحرف {sentence_letter}؟",
                        'options': [meta[1]] + [x[1] for x in alternatives[:2]],
                        'optionImages': [meta[2]] + [x[2] for x in alternatives[:2]],
                        'correctIndex': 0, 'audio': meta[4]}
        question.update(successAudio='assets/audio/taa/assessment_success.mp3',
                        retryAudio='assets/audio/taa/assessment_retry.mp3')
        review['data']['questions'].append(question)
    write(f"assets/content/lesson_{item['id']}.json", lesson)
    packs['packs'].append({
        'id': item['id'], 'version': 1, 'title': f"حرف {item['name']}",
        'letter': item['letter'], 'stageId': 'letters_fatha',
        'priorLessonIds': prior, 'status': 'available',
        'lessonAsset': f"assets/content/lesson_{item['id']}.json",
        'audioFolder': f"assets/audio/{item['id']}/",
        'traceTemplateIds': [item['template']],
        'exampleImages': [f"assets/images/assessment/{item['image']}"],
        'reviewChecklist': checklist})

letter_rows = []
for item in NEW:
    letter_rows.append({
        'id': item['id'], 'letter': item['letter'], 'word': item['word'],
        'image': f"assets/images/assessment/{item['image']}",
        'letterAudio': audio(item, 'assessment_letter'),
        'wordAudio': audio(item, 'assessment_word'),
        'expected': item['spoken'],
        'pronunciationRetryAudio': 'assets/audio/checkpoint_1/retry_only_v51.mp3',
        'traceTemplateId': item['template'],
        'freeAudio': audio(item, 'free_intro')})

checkpoint = copy.deepcopy(read('assets/content/lesson_checkpoint_group_1.json'))
checkpoint.update(id='checkpoint_group_2', title='الاختبار المرحلي الثاني')
checkpoint['mastery']['requiredSceneIds'] = ['checkpoint_2']
cp = next(scene for scene in checkpoint['scenes'] if scene['type'] == 'checkpoint')
cp.update(id='checkpoint_2', title='الاختبار المرحلي الثاني')
cp['data']['standardizedFlow'] = True
cp['data']['letters'] = letter_rows
cp['data']['tasks'] = []
cp['lines'][0]['audio'] = 'assets/audio/checkpoint_2/checkpoint_intro.mp3'
success = next(scene for scene in checkpoint['scenes'] if scene['type'] == 'success')
success['lines'][0]['audio'] = 'assets/audio/checkpoint_2/checkpoint_mastery.mp3'
write('assets/content/lesson_checkpoint_group_2.json', checkpoint)
packs['packs'].append({
    'id': 'checkpoint_group_2', 'version': 1, 'title': 'الاختبار المرحلي الثاني',
    'kind': 'checkpoint', 'stageId': 'letters_fatha',
    'priorLessonIds': ALL, 'status': 'available',
    'lessonAsset': 'assets/content/lesson_checkpoint_group_2.json',
    'audioFolder': 'assets/audio/checkpoint_2/',
    'traceTemplateIds': [x['template'] for x in NEW],
    'exampleImages': [x['image'] for x in letter_rows],
    'reviewChecklist': checklist})
write('assets/content/lesson_packs.json', packs)

programs = read('assets/content/programs.json')
levels = programs[0]['stages'][0]['levels']
levels[:] = [level for level in levels if level['id'] != 'group_2']
levels.append({'id': 'group_2', 'title': 'حروفنا التالية', 'lessons': [
    *[{'lessonId': x['id'], 'title': f"حرف {x['name']}",
       'subtitle': f"{x['letter']} — {x['word']}", 'letter': x['letter']} for x in NEW],
    {'lessonId': 'checkpoint_group_2', 'title': 'الاختبار المرحلي الثاني',
     'subtitle': 'إتقان حروف المجموعة الثانية'}]})
write('assets/content/programs.json', programs)
print('v54 content built: 5 lessons, 30 cumulative review questions, checkpoint 2.')
