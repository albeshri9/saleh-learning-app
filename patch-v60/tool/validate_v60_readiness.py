"""Read-only v60 release prerequisite gate. NEVER marks any asset verified.

Checks real files against manual QA evidence, independently decoded MP3 metadata,
transparent images, the 64 supplied reading sequences, and trace registrations.
Passing this gate permits further integration/release validation, not a build or
a claim that the complete application has passed its UI/learning-track tests.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess

from build_v60_content import LETTERS, ROOT, audio, narration

PENDING = ROOT / "pending_content/v60"
QA_FLAGS = (
    "listenedEntirely", "transcriptChecked", "pronunciationChecked",
    "allRepetitionsChecked",
)
READING_AUDIO = (
    "assets/audio/reading/pair_intro_v60.mp3",
    "assets/audio/reading/triple_intro_v60.mp3",
)
# Independently transcribed from user images; each tuple is in spoken RTL order.
REFERENCE_ROWS = {
    2: ("بح", "دخ", "زس", "تأ", "جث", "ذر", "جز", "رأ", "ثح", "سذ", "خت", "دب"),
    3: ("شح", "طخ", "ظس", "صأ", "عث", "ضر", "جظ", "رض", "ثش", "سع", "خظ", "دص",
        "جد", "ذس", "تز", "سش", "ظع", "بد"),
    4: ("غص", "فظ", "قش", "لط", "مث", "كض", "سل", "بم", "زغ", "شف", "خك", "ذق"),
    5: ("نص", "وظ", "هو", "يه", "من", "يط", "كي", "أكل", "رأس", "صبر", "نظر", "حرث",
        "خدم", "صدق", "ضرع", "غزل", "طرأ", "فتح", "وقف", "وجد", "خذل", "نشر"),
}


def expected_reading_rows(group):
    return [[letter + "َ" for letter in row] for row in REFERENCE_ROWS[group]]


class Issues:
    def __init__(self):
        self.items = {}

    def add(self, category, detail):
        self.items.setdefault(category, []).append(detail)

    def summary(self):
        return [{"category": category, "count": len(details), "examples": details[:3]}
                for category, details in sorted(self.items.items())]


def read_json(path, issues, category):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as error:
        issues.add(category, f"{path.name}: {type(error).__name__}")
        return None


def canonical_asset(value):
    if not isinstance(value, str):
        return None
    value = value.replace("\\", "/")
    prefix = "pending_content/v60/"
    if value.startswith(prefix):
        value = value[len(prefix):]
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or not value.startswith("assets/") or ":" in value:
        return None
    return path.as_posix()


def manifest_rows(document, issues, label):
    """Tolerate common ledger containers but never infer missing QA flags."""
    rows = document
    if isinstance(document, dict):
        rows = next((document[key] for key in ("clips", "assets", "audio") if key in document), document)
    if isinstance(rows, dict):
        rows = [dict(value, asset=value.get("asset", key))
                for key, value in rows.items() if isinstance(value, dict)]
    if not isinstance(rows, list):
        issues.add("manifest-invalid", f"{label}: expected an array/dictionary of clip records")
        return {}
    result = {}
    for row in rows:
        if not isinstance(row, dict):
            issues.add("manifest-invalid", f"{label}: invalid clip row")
            continue
        asset = canonical_asset(row.get("asset", row.get("path", row.get("target"))))
        if asset is None:
            issues.add("manifest-invalid", f"{label}: missing/unsafe asset path")
            continue
        if asset in result:
            issues.add("manifest-duplicate", f"{label}: {asset}")
        result[asset] = row
    return result


def find_ffmpeg(project_root):
    bundled = project_root.parent / "video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"
    return str(bundled) if bundled.is_file() else shutil.which("ffmpeg")


def probe_mp3(path, executable):
    if not executable:
        return None, "ffmpeg is unavailable: real MP3 decoding cannot be checked"
    try:
        result = subprocess.run(
            [str(executable), "-hide_banner", "-v", "info", "-i", str(path),
             "-map", "0:a:0", "-f", "null", "-"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, type(error).__name__
    if result.returncode != 0 or not re.search(r"Audio:\s*mp3", result.stderr):
        return None, "file did not decode as MP3 audio"
    match = re.search(r"Duration:\s*(\d+):(\d+):([\d.]+)", result.stderr)
    if not match:
        return None, "decoded audio has no measured duration"
    hours, minutes, seconds = map(float, match.groups())
    return hours * 3600 + minutes * 60 + seconds, None


def valid_positive_number(value):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value) and value > 0


def validate_audio(asset, record, pending, issues, probe, ffmpeg):
    if record is None:
        issues.add("audio-manifest-row-missing", asset)
        record = {}
    missing_flags = [key for key in QA_FLAGS if record.get(key) is not True]
    if missing_flags:
        issues.add("audio-manual-qa-pending", f"{asset}: {', '.join(missing_flags)}")
    transcript = record.get("independentTranscript")
    if not isinstance(transcript, str) or not transcript.strip():
        issues.add("audio-transcript-missing", asset)
    path = pending / asset
    if not path.is_file() or path.stat().st_size == 0:
        issues.add("audio-missing-or-empty", asset)
        return False
    observed = hashlib.sha256(path.read_bytes()).hexdigest()
    if not isinstance(record.get("sha256"), str) or record["sha256"].lower() != observed:
        issues.add("audio-sha256-mismatch-or-missing", asset)
    if record.get("bytes") != path.stat().st_size:
        issues.add("audio-size-mismatch-or-missing", asset)
    duration, error = probe(path, ffmpeg)
    if error or duration is None:
        issues.add("audio-decode-failed", f"{asset}: {error}")
    elif not valid_positive_number(record.get("durationSec")) or abs(record["durationSec"] - duration) > .08:
        issues.add("audio-duration-mismatch-or-missing", asset)
    return True


def image_has_real_alpha(path):
    try:
        from PIL import Image
        with Image.open(path) as source:
            source.load()
            if "A" not in source.getbands() and "transparency" not in source.info:
                return False, "no alpha channel"
            minimum, maximum = source.convert("RGBA").getchannel("A").getextrema()
            if minimum == 255:
                return False, "alpha is entirely opaque"
            if maximum == 0:
                return False, "image is entirely invisible"
            return True, None
    except (ImportError, OSError, ValueError) as error:
        return False, type(error).__name__


def validate_registry(project_root, expected_ids, issues):
    folder = project_root / "lib/features/lesson/writing"
    try:
        root_source = (folder / "letter_trace_template.dart").read_text(encoding="utf-8")
        source = (folder / "remaining_fatha_templates.g.dart").read_text(encoding="utf-8")
    except OSError as error:
        issues.add("trace-registry-missing", type(error).__name__)
        return 0
    if "part 'remaining_fatha_templates.g.dart';" not in root_source:
        issues.add("trace-registry-unlinked", "remaining template part is not imported")
    if not re.search(r"for\s*\(final template in remainingFathaTemplates\)\s*\{\s*if\s*\(id == template.id\)\s*return template;", root_source):
        issues.add("trace-registry-unlinked", "fromId does not resolve remaining template IDs")
    definitions = re.findall(r"const\s+(\w+)\s*=\s*LetterTraceTemplate\(\s*id:\s*'([^']+)'", source)
    export = re.search(r"const remainingFathaTemplates\s*=\s*<LetterTraceTemplate>\s*\[([^]]+)\]", source)
    exports = re.findall(r"\b\w+FathaTemplate\b", export.group(1)) if export else []
    resolved = [identifier for name, identifier in definitions if name in exports]
    if len(set(exports)) != len(exports) or len(set(resolved)) != len(resolved):
        issues.add("trace-registry-duplicate", "duplicate template names or IDs")
    for identifier in sorted(expected_ids - set(resolved)):
        issues.add("trace-registry-unresolved", identifier)
    for identifier in sorted(set(resolved) - expected_ids):
        issues.add("trace-registry-unexpected", identifier)
    return len(expected_ids & set(resolved))


def validate_reading(pending, issues):
    total = 0
    for group in (2, 3, 4, 5):
        path = pending / f"assets/content/lesson_reading_group_{group}.json"
        lesson = read_json(path, issues, "reading-lesson-missing-or-invalid")
        if not isinstance(lesson, dict):
            continue
        scenes = [s for s in lesson.get("scenes", []) if isinstance(s, dict) and s.get("type") == "reading"]
        if len(scenes) != 1:
            issues.add("reading-scene-invalid", f"group {group}: expected exactly one reading scene")
            continue
        data = scenes[0].get("data", {})
        actual = data.get("items")
        if not isinstance(actual, list):
            issues.add("reading-reference-mismatch", f"group {group}: missing items")
            continue
        total += len(actual)
        if actual != expected_reading_rows(group):
            issues.add("reading-reference-mismatch", f"group {group}: changed order, count, glyph, or fatha")
        if data.get("pairPromptAudio") != READING_AUDIO[0] or data.get("triplePromptAudio") != READING_AUDIO[1]:
            issues.add("reading-audio-binding-mismatch", f"group {group}")
    if total != 64:
        issues.add("reading-total-mismatch", f"expected 64, got {total}")
    return total


def validate(pending=PENDING, project_root=ROOT, probe=probe_mp3, alpha_check=image_has_real_alpha):
    pending, project_root = Path(pending), Path(project_root)
    issues = Issues()
    required_audio = {audio(item, key): text for item in LETTERS for key, text in narration(item).items()}
    narration_doc = read_json(pending / "NARRATION_V60_PENDING.json", issues, "letter-audio-manifest-missing-or-invalid")
    narration_rows = manifest_rows(narration_doc, issues, "letter clips")
    reading_doc = read_json(pending / "READING_AUDIO_QA.json", issues, "reading-audio-manifest-missing-or-invalid")
    reading_rows = manifest_rows(reading_doc, issues, "reading prompts")
    for asset in sorted(set(narration_rows) - set(required_audio)):
        issues.add("audio-unexpected-manifest-row", asset)
    for asset in sorted(set(reading_rows) - set(READING_AUDIO)):
        issues.add("reading-unexpected-manifest-row", asset)
    found_audio = 0
    executable = find_ffmpeg(project_root)
    for asset, text in required_audio.items():
        record = narration_rows.get(asset)
        if record is not None and record.get("text") != text:
            issues.add("audio-script-mismatch", asset)
        found_audio += validate_audio(asset, record, pending, issues, probe, executable)
    for asset in READING_AUDIO:
        found_audio += validate_audio(asset, reading_rows.get(asset), pending, issues, probe, executable)
    found_images = 0
    for item in LETTERS:
        path = pending / item["image"]
        if not path.is_file() or path.stat().st_size == 0:
            issues.add("image-missing-or-empty", item["image"])
            continue
        found_images += 1
        valid, error = alpha_check(path)
        if not valid:
            issues.add("image-alpha-invalid", f"{item['image']}: {error}")
    reading_items = validate_reading(pending, issues)
    templates = validate_registry(project_root, {item["traceTemplateId"] for item in LETTERS}, issues)
    return {
        "canProceedToIntegrationValidation": not issues.items,
        "status": "prerequisites-satisfied-not-a-build-approval" if not issues.items else "pending-no-build",
        "counts": {"requiredAudio": 258, "audioFilesPresent": found_audio,
                   "requiredImages": 16, "imageFilesPresent": found_images,
                   "readingItems": reading_items, "expectedReadingItems": 64,
                   "traceIdsResolved": templates, "expectedTraceIds": 16},
        "blockers": issues.summary(),
        "notes": ["Read-only: no evidence, source file, or QA flag was changed.",
                  "Static registry resolution is not a substitute for the Flutter geometry tests.",
                  "Passing permits further content, audio, image-semantic, UI and learning-track regression validation; it does not trigger a build."],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Output concise machine-readable report")
    args = parser.parse_args()
    report = validate()
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(report["status"])
        print("Files: audio {audioFilesPresent}/{requiredAudio}; images {imageFilesPresent}/{requiredImages}; "
              "reading {readingItems}/{expectedReadingItems}; traces {traceIdsResolved}/{expectedTraceIds}".format(**report["counts"]))
        for issue in report["blockers"]:
            print(f"- {issue['category']}: {issue['count']}")
        print("No source files or QA flags changed. No build triggered.")
    raise SystemExit(0 if report["canProceedToIntegrationValidation"] else 1)


if __name__ == "__main__":
    main()
