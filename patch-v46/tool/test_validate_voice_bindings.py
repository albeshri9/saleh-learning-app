import copy
import json
import unittest
from validate_voice_bindings import ROOT, validate, validate_lesson

class VoiceBindingsTest(unittest.TestCase):
    def lesson(self):
        return json.loads((ROOT/'assets/content/lesson_jeem.json').read_text(encoding='utf-8'))
    def test_valid(self): self.assertEqual(validate(),[])
    def test_rejects_wrong_letter_feedback(self):
        lesson=self.lesson()
        for kind,key in [('pronunciation','retryAudio'),('guidedWriting','guidedPraiseAudio'),('freeWriting','successAudio')]:
            bad=copy.deepcopy(lesson)
            next(s for s in bad['scenes'] if s['type']==kind)['data'][key]='assets/audio/taa/free_success.mp3'
            self.assertTrue(any('wrong-letter' in e for e in validate_lesson(bad)))
    def test_rejects_fatha_narration(self):
        lesson=self.lesson()
        next(s for s in lesson['scenes'] if s['type']=='guidedWriting')['lines'][0]['male']+=' ثم نكتب الفتحة.'
        self.assertTrue(any('fatha' in e for e in validate_lesson(lesson)))
    def test_review_question_must_match_review_target(self):
        lesson=self.lesson()
        review=next(s for s in lesson['scenes'] if s['type']=='review')
        review['data']['questions'][0]['audio']='assets/audio/haa/assessment_1.mp3'
        self.assertTrue(any('wrong-letter' in e for e in validate_lesson(lesson)))
    def test_nasheed_must_match_letter(self):
        lesson=self.lesson()
        next(s for s in lesson['scenes'] if s['type']=='nasheed')['lines'][0]['audio']='assets/audio/v45/taa_nasheed_intro.mp3'
        self.assertTrue(any('wrong-letter' in e for e in validate_lesson(lesson)))
    def test_generic_answer_praise_is_not_pronunciation_praise(self):
        lesson=self.lesson()
        next(s for s in lesson['scenes'] if s['type']=='pronunciation')['data']['successAudio']='assets/audio/taa/assessment_success.mp3'
        self.assertTrue(any('wrong-purpose' in e for e in validate_lesson(lesson)))
    def test_writing_praise_cannot_replace_quiz_feedback(self):
        lesson=self.lesson()
        next(s for s in lesson['scenes'] if s['type']=='multipleChoice')['data']['successAudio']='assets/audio/v46/free_praise.mp3'
        self.assertTrue(any('wrong-purpose' in e for e in validate_lesson(lesson)))

if __name__=='__main__': unittest.main()
