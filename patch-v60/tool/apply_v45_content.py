"""Versioned content correction. Reuses approved clips; never generates TTS."""
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT.parent/'video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,d): (ROOT/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def duration(p):
    log=subprocess.run([str(FFMPEG),'-hide_banner','-i',str(ROOT/p)],capture_output=True,text=True,encoding='utf-8',errors='replace').stderr
    match=re.search(r'Duration: (\d+):(\d+):([\d.]+)',log)
    if not match: raise ValueError(p)
    h,m,s=map(float,match.groups()); return round(h*3600+m*60+s,2)
texts=read('tool/v45_narration.json')
asset=lambda key:f'assets/audio/v45/{key}.mp3'
durations={k:duration(asset(k)) for k in texts}
# Existing recordings have an introductory sentence separated by silence.
# Keep the complete question after that pause; preserve original MP3 assets.
cuts={
    'taa_review_letter':('assets/audio/taa/assessment_1.mp3',3.70),
    'alif_review_word':('assets/audio/alif/assessment_2.mp3',4.00),
    'baa_review_word':('assets/audio/baa/assessment_2.mp3',4.10),
    'taa_review_word':('assets/audio/taa/assessment_2.mp3',4.50),
}
derived={}
for key,(original,start) in cuts.items():
    path=asset(key)
    if not (ROOT/path).exists():
        subprocess.run([str(FFMPEG),'-hide_banner','-loglevel','error','-i',str(ROOT/original),
            '-ss',str(start),'-codec:a','libmp3lame','-b:a','192k',str(ROOT/path)],check=True)
    derived[path]={'source':original,'sourceSha256':hashlib.sha256((ROOT/original).read_bytes()).hexdigest(),
        'startSec':start,'sha256':hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),'durationSec':duration(path)}
write('AUDIO_V45_DERIVED.json',derived)
def line(k): return {'male':texts[k],'female':texts[k],'audio':asset(k),'durationSec':durations[k]}
ids=['alif','baa','taa','thaa','jeem','haa']
lessons={i:read(f'assets/content/lesson_{i}.json') for i in ids}
scene=lambda i,t:next(s for s in lessons[i]['scenes'] if s['type']==t or (t=='assessment' and s['id']=='assessment_1'))
generic_success='assets/audio/taa/assessment_success.mp3'
generic_retry='assets/audio/taa/assessment_retry.mp3'
writing_praise='assets/audio/alif/guided_praise.mp3'
question_audio={'alif':'assets/audio/taa/prior_review_2.mp3',
  'baa':'assets/audio/taa/prior_review_3.mp3','taa':asset('taa_review_letter'),
  'thaa':'assets/audio/thaa/assessment_1.mp3','jeem':'assets/audio/jeem_v44/assessment_1.mp3'}
for i in ids:
    scene(i,'nasheed')['lines']=[line(i+'_nasheed_intro')]
    scene(i,'nasheed')['canSkip']=True
    if i in ['thaa','jeem','haa']:
        pronounce=scene(i,'pronunciation')['data']
        pronounce.update(retryAudio=asset(i+'_pronounce_retry'),successAudio=generic_success)
        guided=scene(i,'guidedWriting')
        guided['lines'][0]=line(i+'_writing_demo')
        guided['data'].update(demoPassDurationMs=round(durations[i+'_writing_demo']*500),
            guidedPraiseAudio=writing_praise, successAudio=writing_praise,
            againAudio=guided['lines'][1]['audio'])
        scene(i,'freeWriting')['data']['successAudio']=writing_praise
    scene(i,'guidedWriting')['canSkip']=True
    if i!='alif':
        review=scene(i,'review'); prior=ids[:ids.index(i)]
        review.update(title='المراجعة القبلية',canSkip=True,lines=[line('review_intro')])
        letters=[]; words=[]
        for previous in prior:
            assessment=scene(previous,'assessment')
            target=scene(previous,'pronunciation')['data']['letter']
            options=[target]+[scene(other,'pronunciation')['data']['letter'] for other in ids if other!=previous][:3]
            letters.append({'kind':'letter','reviewLessonId':previous,'showPrompt':False,
                'prompt':f'أين حرف {target}؟','options':options,'correctIndex':0,
                'audio':question_audio[previous],'successAudio':generic_success,'retryAudio':generic_retry})
            q=copy.deepcopy(assessment['data']['questions'][1])
            q.update(kind='word',reviewLessonId=previous,showPrompt=False,
                audio=asset(previous+'_review_word') if previous in ['alif','baa','taa'] else assessment['data']['secondAudio'],successAudio=generic_success,retryAudio=generic_retry,
                answerAudio=scene(previous,'explanation')['lines'][2]['audio'])
            words.append(q)
        review['data'].update(priorLessonIds=prior,questions=letters+words,
            successAudio=generic_success,retryAudio=generic_retry,completionLabel='نستمع النشيد')
        review['data'].pop('secondAudio',None)
    write(f'assets/content/lesson_{i}.json',lessons[i])
programs=read('assets/content/programs.json')
for program in programs:
    for stage in program['stages']:
        if stage['id']=='madd': stage['title']='المدود'
write('assets/content/programs.json',programs)
write('AUDIO_V45_MANIFEST.json',{asset(k):{'sha256':hashlib.sha256((ROOT/asset(k)).read_bytes()).hexdigest(),
    'text':v,'durationSec':durations[k]} for k,v in texts.items()})
print('Updated 6 lessons, 30 mixed-phase review questions and 13 necessary recordings.')
