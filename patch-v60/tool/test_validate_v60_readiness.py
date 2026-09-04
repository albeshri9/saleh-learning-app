"""Synthetic fixtures only: these tests never edit real pending manifests/QA."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from build_v60_content import LETTERS, audio, narration
from validate_v60_readiness import (
    Issues, QA_FLAGS, READING_AUDIO, canonical_asset, expected_reading_rows,
    image_has_real_alpha, manifest_rows, validate, validate_registry,
)


class ReadinessGateTest(unittest.TestCase):
    def setUp(self):
        self.sandbox = tempfile.TemporaryDirectory(prefix="saleh-v60-gate-test-")
        self.addCleanup(self.sandbox.cleanup)
        self.root = Path(self.sandbox.name)
        self.pending = self.root / "pending"
        self.pending.mkdir()
        self.clips = []
        # Mock-only MP3 bytes: the real MP3 probe would reject these fixtures.
        for item in LETTERS:
            for key, text in narration(item).items():
                self.clips.append(self.fake_clip(audio(item, key), text))
        self.reading_clips = [self.fake_clip(asset, "نص تجريبي") for asset in READING_AUDIO]
        self.write("NARRATION_V60_PENDING.json", {"clips": self.clips})
        self.write("READING_AUDIO_QA.json", {"clips": self.reading_clips})
        for item in LETTERS:
            self.binary(item["image"], b"image-fixture")
        for group in (2, 3, 4, 5):
            self.write(f"assets/content/lesson_reading_group_{group}.json", {
                "scenes": [{"type": "reading", "data": {
                    "items": expected_reading_rows(group),
                    "pairPromptAudio": READING_AUDIO[0], "triplePromptAudio": READING_AUDIO[1],
                }}],
            })
        folder = self.root / "lib/features/lesson/writing"
        folder.mkdir(parents=True)
        (folder / "letter_trace_template.dart").write_text(
            "part 'remaining_fatha_templates.g.dart';\n"
            "for (final template in remainingFathaTemplates) {\n"
            "if (id == template.id) return template;\n}\n", encoding="utf-8")
        self.registry = folder / "remaining_fatha_templates.g.dart"
        names = [item["id"] + "FathaTemplate" for item in LETTERS]
        self.registry.write_text("\n".join(
            f"const {name} = LetterTraceTemplate(id: '{item['traceTemplateId']}');"
            for item, name in zip(LETTERS, names))
            + "\nconst remainingFathaTemplates = <LetterTraceTemplate>[" + ", ".join(names) + "];",
            encoding="utf-8")

    def binary(self, name, data):
        path = self.pending / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def write(self, name, value):
        self.binary(name, json.dumps(value, ensure_ascii=False).encode("utf-8"))

    def fake_clip(self, asset, text):
        data = b"ID3-MOCK-ONLY-" + asset.encode("ascii")
        self.binary(asset, data)
        return {
            "asset": asset, "text": text, "independentTranscript": text,
            "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data),
            "durationSec": 1.5, **{key: True for key in QA_FLAGS},
        }

    def report(self, **overrides):
        return validate(self.pending, self.root,
                        probe=overrides.get("probe", lambda *_: (1.5, None)),
                        alpha_check=overrides.get("alpha_check", lambda _: (True, None)))

    def categories(self, report=None):
        return {issue["category"] for issue in (report or self.report())["blockers"]}

    def test_complete_synthetic_evidence_permits_further_validation_only(self):
        report = self.report()
        self.assertTrue(report["canProceedToIntegrationValidation"])
        self.assertEqual("prerequisites-satisfied-not-a-build-approval", report["status"])
        self.assertEqual(258, report["counts"]["audioFilesPresent"])
        self.assertEqual(16, report["counts"]["imageFilesPresent"])
        self.assertEqual(64, report["counts"]["readingItems"])
        self.assertEqual(16, report["counts"]["traceIdsResolved"])

    def test_pending_letter_flags_never_inferred_from_file_or_transcript(self):
        for clip in self.clips:
            clip.update({key: False for key in QA_FLAGS})
        self.write("NARRATION_V60_PENDING.json", {"clips": self.clips})
        report = self.report()
        self.assertFalse(report["canProceedToIntegrationValidation"])
        issue = next(row for row in report["blockers"] if row["category"] == "audio-manual-qa-pending")
        self.assertEqual(256, issue["count"])
        self.assertLessEqual(len(issue["examples"]), 3)

    def test_reading_manual_listening_blocks_even_when_asr_exact(self):
        self.reading_clips[0]["listenedEntirely"] = False
        self.write("READING_AUDIO_QA.json", {"clips": self.reading_clips})
        self.assertIn("audio-manual-qa-pending", self.categories())

    def test_truthy_strings_do_not_count_as_true_qa(self):
        self.reading_clips[1]["listenedEntirely"] = "true"
        self.write("READING_AUDIO_QA.json", {"clips": self.reading_clips})
        self.assertIn("audio-manual-qa-pending", self.categories())

    def test_detects_changed_audio_content_hash_and_size(self):
        self.binary(self.clips[0]["asset"], b"changed")
        categories = self.categories()
        self.assertIn("audio-sha256-mismatch-or-missing", categories)
        self.assertIn("audio-size-mismatch-or-missing", categories)

    def test_detects_duration_and_decode_failure(self):
        self.assertIn("audio-duration-mismatch-or-missing", self.categories(self.report(probe=lambda *_: (2.4, None))))
        self.assertIn("audio-decode-failed", self.categories(self.report(probe=lambda *_: (None, "not MP3"))))

    def test_missing_audio_not_hidden_by_complete_qa_manifest(self):
        (self.pending / self.clips[0]["asset"]).unlink()
        self.assertIn("audio-missing-or-empty", self.categories())

    def test_empty_manifest_does_not_reduce_required_coverage(self):
        self.write("NARRATION_V60_PENDING.json", {"clips": []})
        report = self.report()
        row = next(row for row in report["blockers"] if row["category"] == "audio-manifest-row-missing")
        self.assertEqual(256, row["count"])
        self.assertFalse(report["canProceedToIntegrationValidation"])

    def test_changed_script_requires_review(self):
        self.clips[0]["text"] = "تعليق حرف آخر"
        self.write("NARRATION_V60_PENDING.json", {"clips": self.clips})
        self.assertIn("audio-script-mismatch", self.categories())

    def test_missing_reading_ledger_fails_without_crash(self):
        (self.pending / "READING_AUDIO_QA.json").unlink()
        self.assertIn("reading-audio-manifest-missing-or-invalid", self.categories())

    def test_missing_image_and_opaque_alpha_both_block(self):
        (self.pending / LETTERS[0]["image"]).unlink()
        report = self.report(alpha_check=lambda _: (False, "opaque"))
        self.assertIn("image-missing-or-empty", self.categories(report))
        self.assertIn("image-alpha-invalid", self.categories(report))

    def test_reading_sequence_wrong_direction_or_fatha_rejected(self):
        path = self.pending / "assets/content/lesson_reading_group_3.json"
        lesson = json.loads(path.read_text(encoding="utf-8"))
        lesson["scenes"][0]["data"]["items"][0].reverse()
        self.write("assets/content/lesson_reading_group_3.json", lesson)
        self.assertIn("reading-reference-mismatch", self.categories())

    def test_reading_count_and_lengths_match_64_image_items(self):
        self.assertEqual([12, 18, 12, 22], [len(expected_reading_rows(g)) for g in (2, 3, 4, 5)])
        fifth = expected_reading_rows(5)
        self.assertEqual(7, sum(len(row) == 2 for row in fifth))
        self.assertEqual(15, sum(len(row) == 3 for row in fifth))
        self.assertTrue(all(len(row) == 2 for g in (2, 3, 4) for row in expected_reading_rows(g)))

    def test_unregistered_template_does_not_resolve(self):
        source = self.registry.read_text(encoding="utf-8")
        source = source.replace("sheenFathaTemplate,", "", 1)
        self.registry.write_text(source, encoding="utf-8")
        self.assertIn("trace-registry-unresolved", self.categories())

    def test_duplicate_registry_entries_rejected(self):
        source = self.registry.read_text(encoding="utf-8")
        self.registry.write_text(source.replace("[sheenFathaTemplate,", "[sheenFathaTemplate, sheenFathaTemplate,"), encoding="utf-8")
        self.assertIn("trace-registry-duplicate", self.categories())

    def test_validates_actual_project_registry_without_dart_import(self):
        from build_v60_content import ROOT
        issues = Issues()
        self.assertEqual(16, validate_registry(ROOT, {x["traceTemplateId"] for x in LETTERS}, issues))
        self.assertEqual([], issues.summary())

    def test_preserves_real_manifest_bytes_and_never_sets_flags(self):
        self.reading_clips[0]["listenedEntirely"] = False
        self.write("READING_AUDIO_QA.json", {"clips": self.reading_clips})
        before = {str(path): path.read_bytes() for path in self.pending.rglob("*") if path.is_file()}
        self.report()
        after = {str(path): path.read_bytes() for path in self.pending.rglob("*") if path.is_file()}
        self.assertEqual(before, after)

    def test_robust_ledger_containers_and_unsafe_paths(self):
        for container in ({"clips": self.reading_clips}, {"assets": self.reading_clips},
                          {clip["asset"]: clip for clip in self.reading_clips}):
            issues = Issues()
            self.assertEqual(set(READING_AUDIO), set(manifest_rows(container, issues, "reading")))
            self.assertEqual([], issues.summary())
        self.assertIsNone(canonical_asset("../../secret.mp3"))
        self.assertIsNone(canonical_asset("C:/private.mp3"))
        self.assertEqual(READING_AUDIO[0], canonical_asset("pending_content/v60/" + READING_AUDIO[0]))

    def test_alpha_is_actual_transparency_not_merely_channel(self):
        from PIL import Image
        path = self.root / "alpha.png"
        for color in ((255, 255, 255, 255), (255, 255, 255, 0)):
            Image.new("RGBA", (2, 1), color).save(path)
            self.assertFalse(image_has_real_alpha(path)[0])
        image = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        image.putpixel((0, 0), (255, 255, 255, 255))
        image.save(path)
        self.assertTrue(image_has_real_alpha(path)[0])


if __name__ == "__main__":
    unittest.main()
