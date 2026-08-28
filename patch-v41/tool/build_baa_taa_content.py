"""Assemble the user-supplied, already approved recordings; never generate TTS."""
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT.parent / 'video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
SOURCE = Path('C:/Users/FIN/Documents/Codex/2026-08-25/elevenlabs-x20/outputs')

def read(name): return json.loads((ROOT / 'assets/content' / name).read_text(encoding='utf-8'))
def write(name, data): (ROOT / 'assets/content' / name).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def duration(path):
    info = subprocess.run([str(FFMPEG), '-hide_banner', '-i', str(path)], capture_output=True, text=True, encoding='utf-8', errors='replace').stderr
    match = re.search(r'Duration: (\d+):(\d+):([\d.]+)', info)
    assert match, path
    h,m,s = map(float,match.groups())
    return round(h*3600+m*60+s,2)

packs = read('lesson_packs.json')
packs['packs'] = [p for p in packs['packs'] if p['id'] not in ('baa','taa')]
packs['packs'][0].update(stageId='letters_fatha', priorLessonIds=[])
programs = read('programs.json')
lessons = [programs[0]['stages'][0]['levels'][0]['lessons'][0]]
lessons[0]['letter'] = 'أَ'
audio_manifest = {}
for slug, name, letter, spoken, word, image, previous, folder in [
    ('baa','الباء','بَ','بَا','بطة','duck.png',['alif'],'حرب البا'),
    ('taa','التاء','تَ','تَا','تاج','crown_v41.png',['alif','baa'],'حرف التا'),
]:
    asset = lambda f: f'assets/audio/{slug}/{f}.mp3'
    texts = {
      'welcome': f'مرحبًا يا أصدقائي، كيف حالكم اليوم؟ سوف نتعلم اليوم حرفًا جديدًا، حرف {name}. هيا بنا.',
      'nasheed_intro': f'هيا نستمع إلى نشيد حرف {name}.',
      'explain_1': f'انظروا يا أصدقائي إلى حرف {name}، إنه حرف جميل.',
      'explain_2': f'{spoken}، {spoken}، {spoken}. هل تعرفون كلمةً تبدأ بحرف {name}؟',
      'explain_3': f'{spoken}، {word}. {spoken}، {word}.',
      'explain_4': f'انظروا إلى كلمة {word}، إنها تبدأ بحرف {name}.',
      'explain_5': f'ردِّدوا معي: {spoken}، {word}. {spoken}، {word}. {spoken}، {word}.',
      'explain_6': f'هكذا يا أصدقائي تعلمنا اليوم حرف {name}. سننتقل الآن إلى نطق وكتابة حرف {name}. هيا بنا.',
      'pronounce_intro': f'هيا يا أصدقائي، سأستمع إلى نطقكم لحرف {name}. {spoken}، {spoken}، {spoken}. اضغطوا على زر المايك وقوموا بنطق الحرف. هيا.',
      'free_intro': f'هيا يا أصدقائي، هل تذكرون كيفية كتابة حرف {name}؟ قوموا بكتابة حرف {name} الآن.',
      'assessment_1': f'الآن يا أصدقائي سأختبر معلوماتكم. أين حرف {name}؟ اضغطوا على حرف {name}.',
      'closing': f'أحسنتم يا أبطال. الحمد لله، لقد تعرفنا هذا اليوم على حرف {name}. {spoken}، {word}. نلقاكم غدًا بإذن الله. إلى اللقاء يا أصدقائي.',
    }
    if slug == 'baa':
        for key in ['explain_2','explain_3','closing']: texts[key] = texts[key].replace('بَا','بَ')
        texts.update(
            prior_review='تعلمنا سابقًا حرف الآ. هل تذكرونه؟ اضغطوا على حرف الآ.',
            writing_demo='انظروا يا أصدقائي كيف نكتب حرف الباء. نبدأ من اليمين، ونسير مع المسار إلى اليسار، ثم نضع نقطةً واحدة تحت الحرف. انظروا مرةً أخرى. نبدأ من اليمين، ونسير مع المسار إلى اليسار، ثم نضع النقطة تحت الحرف.',
            writing_try='هيا يا أصدقائي، اكتبوا حرف الباء. ضعوا إصبعكم على النقطة الخضراء، واتبعوا مسار الحرف، ثم اكتبوا النقطة تحته. بَ، بَ.')
    else:
        texts.update(
            prior_review='تعلمنا سابقًا حرف الآ وحرف الباء. هل تذكرونهما؟',
            prior_review_2='قوموا باختيار حرف الآ.', prior_review_3='قوموا باختيار حرف الباء.',
            writing_demo='انظروا يا أصدقائي كيف نكتب حرف التاء. نبدأ من اليمين، ونسير مع المسار إلى اليسار، ثم نضع نقطتين فوق الحرف. انظروا مرةً أخرى. نبدأ من اليمين، ونسير مع المسار إلى اليسار، ثم نضع النقطتين فوق الحرف.',
            writing_try='هيا يا أصدقائي، اكتبوا حرف التاء. ضعوا إصبعكم على النقطة الخضراء، واتبعوا مسار الحرف، ثم اكتبوا النقطتين فوقه. تَا، تَا.')
    durations = {}
    for path in sorted((ROOT / f'assets/audio/{slug}').glob('*.mp3')):
        original = SOURCE / folder / path.name
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == hashlib.sha256(original.read_bytes()).hexdigest(), path
        durations[path.stem] = duration(path)
        audio_manifest[f'{slug}/{path.name}'] = {'sha256':digest, 'durationSec':durations[path.stem]}
    assert len(durations) == (25 if slug == 'baa' else 27)
    def line(key, events=None):
        result = {'male':texts[key], 'female':texts[key], 'audio':asset(key), 'durationSec':durations[key]}
        if events: result['events'] = events
        return result
    lesson = copy.deepcopy(read('lesson_alif.json'))
    lesson.update(id=slug, title=f'درس حرف {letter}')
    scenes = {s['id']:s for s in lesson['scenes']}
    scenes['welcome_1']['lines'] = [line('welcome', scenes['welcome_1']['lines'][0]['events'])]
    scenes['nasheed_1']['lines'] = [line('nasheed_intro')]
    scenes['nasheed_1']['data']['label'] = f'أنشودة حرف {letter}'
    scenes['explain_1']['lines'] = [line(f'explain_{i}', old.get('events')) for i,old in enumerate(scenes['explain_1']['lines'],1)]
    scenes['explain_1']['data'] = {'letter':letter, 'letterName':name, 'letterAudio':asset('explain_2'), 'example':{'word':word,'imageAsset':f'assets/images/assessment/{image}','highlightPrefix':letter[0]}}
    scenes['pronounce_1']['lines'] = [line('pronounce_intro')]
    scenes['pronounce_1']['data'].update(letter=letter, spokenLetter=spoken, expected=spoken.replace('َ',''), letterAudio=asset('explain_2'))
    scenes['write_guided_1']['lines'] = [line('writing_demo'), line('writing_try')]
    scenes['write_guided_1']['data'].update(guidedPraiseAudio=asset('writing_success'), demoPassDurationMs=round(durations['writing_demo']*500))
    scenes['write_free_1']['lines'] = [line('free_intro')]
    for id in ['write_guided_1','write_free_1']:
        scenes[id]['data'].update(letter=letter, lessonId=slug, traceTemplateId=f'{slug}_fatha_pdf_v1')
    scenes['assessment_1']['lines'] = [line('assessment_1')]
    options = ['أَ','بَ','تَ','ثَ']
    scenes['assessment_1']['data']['questions'] = [
        {'prompt':f'اضغط على حرف {letter}','showPrompt':False,'options':options,'correctIndex':options.index(letter)},
        {'prompt':f'ما الكلمة التي تبدأ بحرف {letter}؟','showPrompt':False,'options':[word,'أسد','ثعلب' if slug=='baa' else 'بطة'], 'optionImages':[f'assets/images/assessment/{image}','assets/images/assessment/alif_lion.png',f'assets/images/assessment/{"fox.png" if slug=="baa" else "duck.png"}'],'correctIndex':0},
    ]
    closing_events = copy.deepcopy(scenes['success_1']['lines'][0]['events'])
    closing_events[-1]['atSec'] = max(0,durations['closing']-2.8)
    scenes['success_1']['lines'] = [line('closing', closing_events)]
    # Replace remaining generic feedback references, not approved Alif content.
    def retarget(value):
        if isinstance(value,str): return value.replace('assets/audio/alif/',f'assets/audio/{slug}/')
        if isinstance(value,list): return [retarget(x) for x in value]
        if isinstance(value,dict): return {k:retarget(v) for k,v in value.items()}
        return value
    lesson = retarget(lesson)
    questions = []
    for index, prior in enumerate(previous):
        target = {'alif':'أَ','baa':'بَ'}[prior]
        q = {'reviewLessonId':prior,'prompt':f'أين حرف {target}؟', 'options':options,'correctIndex':options.index(target)}
        if index > 0: q['audio'] = asset(f'prior_review_{index+2}')
        if index < len(previous)-1: q['successAudio'] = asset('assessment_success')
        questions.append(q)
    review = {'id':'prior_review_1','type':'review','title':'نتذكر معًا','canSkip':False,
        'lines':[line('prior_review')] + ([line('prior_review_2')] if slug=='taa' else []),
        'data':{'priorLessonIds':previous,'questions':questions,'successAudio':asset('prior_review_success'), 'retryAudio':asset('prior_review_retry'),'completionLabel':'نبدأ الحرف الجديد'}}
    lesson['scenes'].insert(1,review)
    write(f'lesson_{slug}.json',lesson)
    packs['packs'].append({'id':slug,'version':1,'title':f'حرف {name}','letter':letter,'stageId':'letters_fatha','priorLessonIds':previous,'status':'available','lessonAsset':f'assets/content/lesson_{slug}.json','audioFolder':f'assets/audio/{slug}/','traceTemplateIds':[f'{slug}_fatha_pdf_v1'],'exampleImages':[f'assets/images/assessment/{image}'],'reviewChecklist':packs['packs'][0]['reviewChecklist']})
    lessons.append({'lessonId':slug,'title':f'حرف {name}','subtitle':f'{letter} — {word}','letter':letter})

stages = [('letters_fatha','الحروف بحركة الفتح'),('letters_kasra','الحروف بحركة الكسر'),('letters_damma','الحروف بحركة الضم'),('sukun','السكون'),('madd','الممدود'),('shadda','التشديد'),('tanween','التنوين')]
programs[0]['stages'] = [{'id':id,'title':title,'levels':([{'id':'group_1','title':'حروفنا الأولى','lessons':lessons}] if i==0 else [])} for i,(id,title) in enumerate(stages)]
write('programs.json',programs)
write('lesson_packs.json',packs)
(ROOT / 'AUDIO_V41_MANIFEST.json').write_text(json.dumps(audio_manifest,indent=2)+'\n',encoding='utf-8')
print('Created 2 lessons, 3 cumulative review questions, 7 stages; verified 52 audio hashes.')
