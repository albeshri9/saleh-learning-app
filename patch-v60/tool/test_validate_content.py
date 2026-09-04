import copy
import json
import unittest
from pathlib import Path
from unittest.mock import patch
from validate_content import ROOT, validate


class ContentValidationTest(unittest.TestCase):
    def test_rejects_incomplete_cumulative_review(self):
        original_read = Path.read_text
        bad = json.loads(original_read(ROOT / 'assets/content/lesson_taa.json', encoding='utf-8'))
        review = next(s for s in bad['scenes'] if s['type'] == 'review')
        review['data']['questions'].pop()
        def read(path, *args, **kwargs):
            if path.name == 'lesson_taa.json':
                return json.dumps(bad)
            return original_read(path, *args, **kwargs)
        with patch.object(Path, 'read_text', read):
            self.assertTrue(any('prior letters' in e or 'previous letters' in e for e in validate()))

    def test_valid_package(self):
        self.assertEqual(validate(), [])

    def test_rejects_wrong_answer_and_missing_asset(self):
        original_read = Path.read_text
        lesson = json.loads(original_read(ROOT / 'assets/content/lesson_alif.json', encoding='utf-8'))
        bad = copy.deepcopy(lesson)
        question = next(s['data']['questions'][0] for s in bad['scenes'] if s['data'].get('questions'))
        question['correctIndex'] = 999
        bad['scenes'][0]['lines'][0]['audio'] = 'assets/audio/nonexistent-v38.mp3'
        def read(path, *args, **kwargs):
            if path.name == 'lesson_alif.json':
                return json.dumps(bad)
            return original_read(path, *args, **kwargs)
        with patch.object(Path, 'read_text', read):
            errors = validate()
        self.assertTrue(any('invalid answer index' in e for e in errors))
        self.assertTrue(any('Missing/unsafe asset' in e for e in errors))


if __name__ == '__main__':
    unittest.main()
