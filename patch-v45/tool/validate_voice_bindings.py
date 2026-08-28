"""Reject wrong-letter narration references before publishing a lesson."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = ['alif','baa','taa','thaa','jeem','haa']
# Explicitly reviewed, letter-neutral recordings. Do not whitelist a folder.
SHARED = {
    'assets/audio/taa/assessment_success.mp3': 'ممتاز! أحسنتم، إجابة صحيحة.',
    'assets/audio/taa/assessment_retry.mp3': 'حاولوا مرةً أخرى.',
    'assets/audio/alif/guided_praise.mp3': 'أحسنتم، لقد قمتم بكتابة الحرف بطريقة جميلة.',
    'assets/audio/v45/review_intro.mp3': 'الآن يا أصدقائي سأختبر معلوماتكم السابقة.',
}
REVIEW_QUESTIONS = {
    'assets/audio/taa/prior_review_2.mp3':'alif',
    'assets/audio/taa/prior_review_3.mp3':'baa',
}

def validate_lesson(lesson):
    errors=[]
    owner=lesson['id']
    def visit(value, expected, context):
        if isinstance(value,str) and value.startswith('assets/audio/'):
            if value in SHARED: return
            if context=='review' and value in REVIEW_QUESTIONS:
                actual=REVIEW_QUESTIONS[value]
            else:
                folder=value.split('/')[2]
                actual=value.split('/')[-1].split('_')[0] if folder=='v45' else folder.split('_')[0]
            if actual != expected:
                errors.append(f'{owner}: wrong-letter audio for {expected}: {value}')
        elif isinstance(value,list):
            for item in value: visit(item,expected,context)
        elif isinstance(value,dict):
            for item in value.values(): visit(item,expected,context)
    for scene in lesson['scenes']:
        if scene['type']=='review':
            visit(scene['lines'],owner,'review')
            for key,value in scene['data'].items():
                if key!='questions': visit(value,owner,'review')
            for q in scene['data']['questions']:
                visit(q,q['reviewLessonId'],'review')
        else:
            visit(scene,owner,'lesson')
        if scene['type'] in ['guidedWriting','explanation']:
            for line in scene['lines']:
                for key in ['male','female']:
                    if 'فتحة' in line.get(key,''):
                        errors.append(f'{owner}: spoken fatha instruction is not allowed')
    return errors

def validate():
    return [e for i in IDS for e in validate_lesson(json.loads((ROOT/f'assets/content/lesson_{i}.json').read_text(encoding='utf-8')))]

if __name__=='__main__':
    errors=validate()
    if errors: raise SystemExit('\n'.join(errors))
    print('Voice bindings passed: all 6 lessons match their letters; reviewed shared clips only.')
