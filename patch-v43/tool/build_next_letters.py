"""Assemble v43 from saved ElevenLabs outputs; never generate or retry audio."""
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT.parent / 'video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
def read(path): return json.loads((ROOT/path).read_text(encoding='utf-8'))
def write(path, data): (ROOT/path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def duration(path):
    result = subprocess.run([str(FFMPEG),'-hide_banner','-i',str(ROOT/path)],capture_output=True,text=True,encoding='utf-8',errors='replace').stderr
    match = re.search(r'Duration: (\d+):(\d+):([\d.]+)',result)
    if not match: raise ValueError(f'Missing or invalid audio: {path}')
    h,m,s=map(float,match.groups())
    return round(h*3600+m*60+s,2)

configs=read('tool/v43_narration.json')
programs=read('assets/content/programs.json')
packs=read('assets/content/lesson_packs.json')
new_ids={c['id'] for c in configs}
packs['packs']=[p for p in packs['packs'] if p['id'] not in new_ids]
lessons=programs[0]['stages'][0]['levels'][0]['lessons']
lessons[:]=[l for l in lessons if l['lessonId'] not in new_ids]
letters={'alif':'أَ','baa':'بَ','taa':'تَ',**{c['id']:c['letter'] for c in configs}}
review_audio={'alif':'assets/audio/taa/prior_review_2.mp3','baa':'assets/audio/taa/prior_review_3.mp3','taa':'assets/audio/taa/assessment_1.mp3',**{c['id']:f"assets/audio/{c['id']}/assessment_1.mp3" for c in configs}}
manifest={}
for c in configs:
    slug=c['id']; letter=c['letter']; word=c['word']; image='assets/images/assessment/'+c['image']
    asset=lambda key:f'assets/audio/{slug}/{key}.mp3'
    durations={key:duration(asset(key)) for key in c['texts']}
    for key in c['texts']:
        path=asset(key)
        manifest[path]={'sha256':hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),'durationSec':durations[key],'text':c['texts'][key]}
    def line(key,events=None):
        result={'male':c['texts'][key],'female':c['texts'][key],'audio':asset(key),'durationSec':durations[key]}
        if events: result['events']=copy.deepcopy(events)
        return result
    lesson=copy.deepcopy(read('assets/content/lesson_taa.json'))
    lesson.update(id=slug,title=f'درس حرف {letter}')
    scenes={s['id']:s for s in lesson['scenes']}
    scenes['welcome_1']['lines']=[line('welcome',scenes['welcome_1']['lines'][0].get('events'))]
    scenes['nasheed_1']['lines']=[]
    scenes['nasheed_1']['data']['label']=f'أنشودة حرف {letter}'
    scenes['explain_1']['lines']=[line(f'explain_{i}',old.get('events')) for i,old in enumerate(scenes['explain_1']['lines'],1)]
    scenes['explain_1']['data']={'letter':letter,'letterName':c['name'],'letterAudio':asset('explain_2'),'example':{'word':word,'imageAsset':image,'highlightPrefix':letter}}
    scenes['pronounce_1']['lines']=[line('pronounce_intro')]
    scenes['pronounce_1']['data'].update(letter=letter,spokenLetter=c['spoken'],expected=c['spoken'],letterAudio=asset('explain_2'))
    scenes['write_guided_1']['lines']=[line('writing_demo'),line('writing_try')]
    scenes['write_guided_1']['data']['demoPassDurationMs']=round(durations['writing_demo']*500)
    scenes['write_free_1']['lines']=[line('free_intro')]
    for scene_id in ['write_guided_1','write_free_1']:
        scenes[scene_id]['data'].update(letter=letter,lessonId=slug,traceTemplateId=f'{slug}_fatha_pdf_v1')
    # Four compact choices per question; review coverage grows, not board height.
    def choices(target): return [target]+[x for x in letters.values() if x!=target][:3]
    scenes['assessment_1']['lines']=[line('assessment_1')]
    scenes['assessment_1']['data'].update(secondAudio=asset('assessment_2'),questions=[
        {'prompt':f'اضغط على حرف {letter}','showPrompt':False,'options':choices(letter),'correctIndex':0},
        {'prompt':f'ما الكلمة التي تبدأ بحرف {letter}؟','showPrompt':False,'options':[word,'أَسد','بَطة'],'optionImages':[image,'assets/images/assessment/alif_lion.png','assets/images/assessment/duck.png'],'correctIndex':0}])
    events=copy.deepcopy(scenes['success_1']['lines'][0]['events'])
    events[-1]['atSec']=max(0,durations['closing']-2.8)
    scenes['success_1']['lines']=[line('closing',events)]
    review=scenes['prior_review_1']
    review['lines']=[{'male':'قوموا باختيار حرف الآ.','female':'قوموا باختيار حرف الآ.','audio':review_audio['alif'],'durationSec':duration(review_audio['alif'])}]
    review['data']['priorLessonIds']=c['prior']
    review['data']['questions']=[]
    for index,prior in enumerate(c['prior']):
        q={'reviewLessonId':prior,'prompt':f'أين حرف {letters[prior]}؟','options':choices(letters[prior]),'correctIndex':0}
        if index: q['audio']=review_audio[prior]
        if index<len(c['prior'])-1: q['successAudio']='assets/audio/taa/assessment_success.mp3'
        review['data']['questions'].append(q)
    write(f'assets/content/lesson_{slug}.json',lesson)
    packs['packs'].append({'id':slug,'version':1,'title':f"حرف {c['name']}",'letter':letter,'stageId':'letters_fatha','priorLessonIds':c['prior'],'status':'available','lessonAsset':f'assets/content/lesson_{slug}.json','audioFolder':f'assets/audio/{slug}/','traceTemplateIds':[f'{slug}_fatha_pdf_v1'],'exampleImages':[image],'reviewChecklist':packs['packs'][0]['reviewChecklist']})
    lessons.append({'lessonId':slug,'title':f"حرف {c['name']}",'subtitle':f'{letter} — {word}','letter':letter})
write('assets/content/programs.json',programs)
write('assets/content/lesson_packs.json',packs)
write('AUDIO_V43_MANIFEST.json',manifest)
print(f'Built 3 lessons, 12 cumulative review questions, {len(manifest)} unique audio files; shared feedback reused.')
