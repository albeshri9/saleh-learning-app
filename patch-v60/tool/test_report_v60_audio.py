import json
from pathlib import Path
import tempfile
import unittest

from report_v60_audio import report


class AudioReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.row = dict(letterId='sheen', key='welcome',
                        asset='assets/audio/sheen/welcome_v60.mp3', text='حرف الشَا',
                        listenedEntirely=False, pronunciationChecked=False,
                        allRepetitionsChecked=False, transcriptChecked=False)
        self.write('NARRATION_V60_PENDING.json', {'clips': [self.row]})

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding='utf-8')

    def generated(self, **overrides):
        self.write('generation_records/sheen/welcome.json',
                   {**self.row, 'independentTranscript': 'حرف الشَا',
                    'transcriptChecked': True, **overrides})
        path = self.root / self.row['asset']
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b'fixture-decoder-is-injected')

    def run_report(self, decode=lambda *_: (2.4, None)):
        return report(self.root, self.root, decode)

    def test_exact_transcript_and_decodable_file_do_not_approve_listening(self):
        self.generated()
        before = (self.root / 'NARRATION_V60_PENDING.json').read_bytes()
        result = self.run_report()
        self.assertEqual(result['summary']['decodedMp3'], 1)
        self.assertEqual(result['summary']['auditoryReviewPending'], 1)
        clip = result['manifest']['clips'][0]
        self.assertFalse(clip['listenedEntirely'])
        self.assertFalse(clip['pronunciationChecked'])
        self.assertFalse(clip['allRepetitionsChecked'])
        self.assertEqual(len(clip['sha256']), 64)
        self.assertEqual(result['metadata'][0]['durationSec'], 2.4)
        self.assertEqual(before, (self.root / 'NARRATION_V60_PENDING.json').read_bytes())

    def test_changed_script_is_not_merged(self):
        self.generated(text='حرف مختلف')
        self.assertIn('record/script mismatch', str(self.run_report()['summary']['issues']))

    def test_changed_file_hash_is_rejected(self):
        self.generated(sha256='0' * 64)
        result = self.run_report()
        self.assertIn('file changed', str(result['summary']['issues']))
        self.assertEqual([], result['metadata'])

    def test_decoding_failure_remains_an_issue(self):
        self.generated()
        self.assertIn('not mp3', str(self.run_report(lambda *_: (None, 'not mp3'))['summary']['issues']))

    def test_missing_request_is_not_treated_as_generated(self):
        result = self.run_report()
        self.assertEqual(result['summary']['notDispatched'], 1)
        self.assertNotIn('decodedMp3', result['summary'])


if __name__ == '__main__':
    unittest.main()
