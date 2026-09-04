import unittest

from audit_v60_local_asr import cache_matches, comparison


class LocalAsrAuditTest(unittest.TestCase):
    def test_diacritics_and_punctuation_do_not_imply_listening(self):
        result = comparison('صَا، صَقْر.', 'صا صقر')
        self.assertTrue(result['normalizedTextMatches'])
        self.assertFalse(result['listenedEntirely'])
        self.assertFalse(result['pronunciationApproved'])

    def test_article_repetition_and_added_hamza_are_preserved(self):
        for heard in ('حرف صا', 'حرف الصاء', 'حرف الصا الصا'):
            self.assertFalse(comparison('حرف الصَا', heard)['normalizedTextMatches'])
        self.assertFalse(comparison('صَا، صَا، صَا.', 'صا صا')['normalizedTextMatches'])

    def test_changed_word_is_a_review_candidate(self):
        self.assertFalse(comparison('صا صقر', 'صا سكر')['normalizedTextMatches'])

    def test_cache_requires_same_asset_bytes_and_script(self):
        old = {'asset': 'a.mp3', 'sha256': 'abc', 'expectedText': 'صا',
               'transcript': 'صا', 'method': 'local-faster-whisper-small-unprompted'}
        self.assertTrue(cache_matches(old, 'a.mp3', 'abc', 'صا'))
        self.assertFalse(cache_matches(old, 'a.mp3', 'changed', 'صا'))
        self.assertFalse(cache_matches(old, 'a.mp3', 'abc', 'سا'))
        self.assertFalse(cache_matches(old, 'other.mp3', 'abc', 'صا'))


if __name__ == '__main__':
    unittest.main()
