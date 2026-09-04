"""Structural checks only; no claim of audio/image/trace QA or playable release."""
import copy
import unittest

from build_v60_content import LETTERS, audio, build_bundle, narration, validate_bundle


class PendingV60ContentTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = build_bundle()

    def lesson(self, identifier):
        return self.files[f"assets/content/lesson_{identifier}.json"]

    def test_valid_authored_structure(self):
        self.assertEqual([], validate_bundle(self.files))

    def test_user_word_corrections_and_initial_fatha(self):
        by_id = {x["id"]: x for x in LETTERS}
        self.assertEqual("عَلَمٌ", by_id["ayn"]["word"])
        self.assertEqual("مَوْز", by_id["meem"]["word"])
        self.assertEqual("فَتْح", by_id["faa"]["word"])
        for item in LETTERS:
            self.assertTrue(item["word"].startswith(item["letter"]))

    def test_all_16_unique_letters_and_256_unique_required_clips(self):
        self.assertEqual(16, len(LETTERS))
        self.assertEqual(16, len({x["id"] for x in LETTERS}))
        clips = self.files["NARRATION_V60_PENDING.json"]["clips"]
        self.assertEqual(256, len(clips))
        self.assertEqual(256, len({clip["asset"] for clip in clips}))

    def test_never_claims_media_qa(self):
        manifest = self.files["NARRATION_V60_PENDING.json"]
        self.assertEqual("eleven_v3", manifest["modelId"])
        self.assertEqual("zAHOVUiYXuxggpSljiCQ", manifest["voiceId"])
        self.assertEqual({}, manifest["additionalVoiceSettings"])
        for clip in manifest["clips"]:
            self.assertEqual("not-generated", clip["status"])
            for key in ("sha256", "bytes", "durationSec", "independentTranscript"):
                self.assertIsNone(clip[key])
            for key in ("listenedEntirely", "transcriptChecked", "allRepetitionsChecked", "pronunciationChecked"):
                self.assertFalse(clip[key])

    def test_exact_triple_tap_with_no_followup_question(self):
        for item in LETTERS:
            text = narration(item)["tap_repeat_3"]
            self.assertEqual("، ".join([item["spoken"]] * 3) + ".", text)
            pronunciation = next(s for s in self.lesson(item["id"])["scenes"] if s["type"] == "pronunciation")
            self.assertEqual(audio(item, "tap_repeat_3"), pronunciation["data"]["letterTapAudio"])
            self.assertEqual(pronunciation["data"]["letterTapAudio"], pronunciation["data"]["letterAudio"])

    def test_tah_zah_narration_follows_long_stroke_before_body(self):
        for item in LETTERS:
            if item["id"] not in ("tah", "zah"):
                continue
            text = narration(item)["writing_demo"]
            self.assertLess(text.index("نبدأ بالخط الطويل"), text.index("ثم نتبع مسار جسم الحرف"))
            self.assertNotIn("فتحة", text)
            if item["id"] == "zah":
                self.assertGreater(text.index("ثم نضع نقطة فوقه"), text.index("ثم نتبع مسار جسم الحرف"))

    def test_same_lesson_sequence_and_first_letter_without_prereview(self):
        base = ["welcome", "nasheed", "explanation", "pronunciation", "guidedWriting", "freeWriting", "multipleChoice", "success"]
        for item in LETTERS:
            expected = base[:]
            if item["id"] not in ("sheen", "ghayn", "noon"):
                expected.insert(1, "review")
            self.assertEqual(expected, [s["type"] for s in self.lesson(item["id"])["scenes"]])

    def test_review_has_both_candidates_for_runtime_disjoint_split(self):
        for item in LETTERS:
            prior = [x["id"] for x in LETTERS[:LETTERS.index(item)] if x["group"] == item["group"]]
            reviews = [s for s in self.lesson(item["id"])["scenes"] if s["type"] == "review"]
            if not prior:
                self.assertEqual([], reviews)
                continue
            data = reviews[0]["data"]
            self.assertEqual(prior, data["priorLessonIds"])
            for identifier in prior:
                rows = [q for q in data["questions"] if q["reviewLessonId"] == identifier]
                self.assertEqual({"letter", "word"}, {q["kind"] for q in rows})
                for q in rows:
                    self.assertGreaterEqual(len(q["options"]), 2)
                    self.assertFalse(q["showPrompt"])
                    self.assertEqual(len(q["options"]), len(set(q["options"])))

    def test_checkpoint_is_cumulative_and_only_free_writing_current_group(self):
        for number, count in ((3, 18), (4, 24), (5, 28)):
            lesson = self.lesson(f"checkpoint_group_{number}")
            self.assertFalse(any(s["type"] == "guidedWriting" for s in lesson["scenes"]))
            data = next(s["data"] for s in lesson["scenes"] if s["type"] == "checkpoint")
            self.assertEqual(count, len(data["letters"]))
            self.assertEqual("alif", data["letters"][0]["id"])
            self.assertEqual([6, 8, 4], [data["recognitionCount"], data["dragMatchCount"], data["pronunciationCount"]])
            self.assertEqual([x["id"] for x in LETTERS if x["group"] == number], data["writingLetterIds"])

    def test_all_experimental_skips_enabled(self):
        for path, value in self.files.items():
            if path.startswith("assets/content/"):
                self.assertTrue(all(s["canSkip"] for s in value["scenes"]))

    def test_outer_names_are_conventional_inner_names_phonemic(self):
        packs = self.files["LESSON_PACKS_ADDITIONS.json"]["packs"]
        for item in LETTERS:
            pack = next(p for p in packs if p["id"] == item["id"])
            self.assertEqual(f"حرف {item['name']}", pack["title"])
            self.assertEqual(f"درس حرف {item['article']}", self.lesson(item["id"])["title"])
            self.assertTrue(item["article"].startswith("ال"))
            self.assertFalse(item["spoken"].endswith("ء"))

    def test_reading_insertions_follow_each_checkpoint(self):
        additions = self.files["PROGRAM_LEVELS_ADDITIONS.json"]
        self.assertEqual("checkpoint_group_2", additions["existingLevelInsertions"][0]["afterLessonId"])
        for level in additions["levels"]:
            number = int(level["id"][-1])
            self.assertEqual(f"checkpoint_group_{number}", level["lessons"][-2]["lessonId"])
            self.assertEqual(f"reading_group_{number}", level["lessons"][-1]["lessonId"])

    def test_validator_catches_foreign_review_and_fake_duration(self):
        bad = copy.deepcopy(self.files)
        lesson = bad["assets/content/lesson_saad.json"]
        lesson["scenes"][0]["lines"][0]["durationSec"] = 4.2
        next(s for s in lesson["scenes"] if s["type"] == "review")["data"]["questions"][0]["reviewLessonId"] = "alif"
        errors = validate_bundle(bad)
        self.assertTrue(any("duration" in error for error in errors))
        self.assertTrue(any("scope" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
