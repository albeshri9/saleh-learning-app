"""Author the remaining fatha lessons in a quarantined, NOT deployable bundle.

This tool never edits assets/, programs.json, lesson_packs.json or pubspec.yaml.
The current seen lesson supplies the scene/animation/interaction template; the
current dal lesson establishes the no-prereview first-letter rule. New media
references are intentional requirements, NOT claims that media exists or passed
review. Run the dedicated tests before running ``python tool/build_v60_content.py``.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "pending_content" / "v60"
RETRY = "assets/audio/checkpoint_1/retry_only_v51.mp3"
SUCCESS = "assets/audio/taa/assessment_success.mp3"
SOURCE_FILES = (
    "assets/content/lesson_seen.json",
    "assets/content/lesson_dal.json",
    "assets/content/lesson_checkpoint_group_2.json",
    "assets/content/lesson_packs.json",
    "VOICEOVER_SETTINGS.md",
)


def letter(identifier, group, glyph, name, word, concept, shape):
    spoken = glyph + "ا"
    return {
        "id": identifier, "group": group, "letter": glyph,
        "name": name, "spoken": spoken, "article": "ال" + spoken,
        "word": word, "imageConcept": concept,
        "image": f"assets/images/assessment/{identifier}_v60.png",
        "traceTemplateId": f"{identifier}_fatha_pdf_v1",
        "writing": shape,
    }


# The words are user-selected. Initial fatha is mandatory in every display.
# AYN is a FLAG (عَلَمٌ), not a scholar/world (عالِم/عالَم).
LETTERS = [
    letter("sheen", 3, "شَ", "الشين", "شَمْس", "sun",
           "نبدأ من اليمين، ونتبع تعرجات الحرف، ثم نكمل الانحناءة إلى اليسار حتى نهاية الحرف، ثم نضع ثلاث نقاط فوقه."),
    letter("saad", 3, "صَ", "الصاد", "صَقْر", "falcon",
           "نتبع مسار جسم الحرف من نقطة البداية حتى النهاية، ونكمل انحناءاته."),
    letter("daad", 3, "ضَ", "الضاد", "ضَابِط", "officer",
           "نتبع مسار جسم الحرف من نقطة البداية حتى النهاية، ونكمل انحناءاته، ثم نضع نقطة فوقه."),
    letter("tah", 3, "طَ", "الطاء", "طَبِيب", "doctor",
           "نبدأ بالخط الطويل، ثم نتبع مسار جسم الحرف حتى النهاية."),
    letter("zah", 3, "ظَ", "الظاء", "ظَرْف", "envelope",
           "نبدأ بالخط الطويل، ثم نتبع مسار جسم الحرف حتى النهاية، ثم نضع نقطة فوقه."),
    letter("ayn", 3, "عَ", "العين", "عَلَمٌ", "flag, NOT scholar or world",
           "نتبع مسار جسم الحرف من نقطة البداية، ونكمل انحناءاته حتى النهاية."),
    letter("ghayn", 4, "غَ", "الغين", "غَزَال", "gazelle",
           "نتبع مسار جسم الحرف من نقطة البداية، ونكمل انحناءاته حتى النهاية، ثم نضع نقطة فوقه."),
    letter("faa", 4, "فَ", "الفاء", "فَتْح", "opening; user-selected word, depiction needs semantic review",
           "نتبع مسار جسم الحرف من نقطة البداية حتى النهاية، ثم نضع نقطة فوقه."),
    letter("qaaf", 4, "قَ", "القاف", "قَلَم", "pen",
           "نتبع مسار جسم الحرف من نقطة البداية حتى النهاية، ثم نضع نقطتين فوقه."),
    letter("kaaf", 4, "كَ", "الكاف", "كَلْب", "dog",
           "نتبع مسار جسم الحرف من نقطة البداية حتى النهاية، ثم نكمل العلامة داخل الحرف."),
    letter("laam", 4, "لَ", "اللام", "لَحْم", "meat",
           "نتبع مسار الخط الطويل، ثم نكمل انحناءة الحرف إلى اليسار حتى النهاية."),
    letter("meem", 4, "مَ", "الميم", "مَوْز", "banana fruit, NOT موزون",
           "نتبع مسار رأس الحرف، ثم نكمل بقية جسم الحرف حتى النهاية."),
    letter("noon", 5, "نَ", "النون", "نَحْل", "bees",
           "نتبع مسار جسم الحرف من نقطة البداية حتى النهاية، ثم نضع نقطة فوقه."),
    letter("heh", 5, "هَ", "الهاء", "هَرَم", "pyramid",
           "نتبع مسار جسم الحرف من نقطة البداية، ونكمل انحناءته حتى النهاية."),
    letter("waw", 5, "وَ", "الواو", "وَلَد", "boy",
           "نتبع مسار رأس الحرف، ثم نكمل انحناءته إلى أسفل اليسار حتى النهاية."),
    letter("yaa", 5, "يَ", "الياء", "يَد", "hand",
           "نتبع مسار جسم الحرف من نقطة البداية حتى النهاية، ثم نضع نقطتين تحته."),
]


def read(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8-sig"))


def audio(item, key):
    return f"assets/audio/{item['id']}/{key}_v60.mp3"


def narration(item):
    article, spoken, word = item["article"], item["spoken"], item["word"]
    return {
        "welcome": f"مرحبًا يا أصدقائي، كيف حالكم اليوم؟ سوف نتعلم اليوم حرفًا جديدًا، حرف {article}. هيا بنا.",
        "nasheed_intro": f"الآن نستمع نشيد حرف {article}.",
        "explain_1": f"انظروا يا أصدقائي إلى حرف {article}، إنه حرف جميل.",
        "explain_2": f"{spoken}، {spoken}، {spoken}. هل تعرفون كلمةً تبدأ بحرف {article}؟",
        "explain_3": f"{spoken}، {word}. {spoken}، {word}.",
        "explain_4": f"انظروا إلى كلمة {word}، إنها تبدأ بحرف {article}.",
        "explain_5": f"ردِّدوا معي: {spoken}، {word}. {spoken}، {word}. {spoken}، {word}.",
        "explain_6": f"هكذا يا أصدقائي تعلمنا اليوم حرف {article}. سننتقل الآن إلى نطق وكتابة حرف {article}. هيا بنا.",
        "pronounce_intro": f"هيا يا أصدقائي، سأستمع إلى نطقكم لحرف {article}. {spoken}، {spoken}، {spoken}. اضغطوا على زر المايك وقوموا بنطق الحرف. هيا.",
        "tap_repeat_3": f"{spoken}، {spoken}، {spoken}.",
        "writing_demo": f"انظروا يا أصدقائي كيف نكتب حرف {article}. {item['writing']}",
        "writing_try": f"هيا يا أصدقائي، اكتبوا حرف {article}. ضعوا إصبعكم على النقطة الخضراء، واتبعوا مسار الحرف حتى النهاية. {spoken}، {spoken}.",
        "free_intro": f"هيا يا أصدقائي، هل تذكرون كيفية كتابة حرف {article}؟ قوموا بكتابة حرف {article} الآن.",
        "assessment_letter": f"أين حرف {article}؟ اضغطوا على حرف {article}.",
        "assessment_word": f"أين الصورة التي تبدأ بحرف {article}؟ اختاروا الصورة الصحيحة.",
        "closing": f"أحسنتم يا أبطال. الحمد لله، لقد تعرفنا هذا اليوم على حرف {article}. {spoken}، {word}. إلى اللقاء يا أصدقائي.",
    }


def bind_line(line, item, key, text):
    line.update(male=text, female=text, audio=audio(item, key))
    # Timing from another letter is not measured timing for this new recording.
    line.pop("durationSec", None)


def question(target, candidates, kind):
    unique = {target["id"]: target}
    unique.update({item["id"]: item for item in candidates})
    values = list(unique.values())
    is_word = kind == "word"
    result = {
        "kind": kind, "reviewLessonId": target["id"], "showPrompt": False,
        "prompt": narration(target)["assessment_word" if is_word else "assessment_letter"],
        "options": [item["word" if is_word else "letter"] for item in values],
        "correctIndex": 0,
        "audio": audio(target, "assessment_word" if is_word else "assessment_letter"),
        "successAudio": SUCCESS, "retryAudio": RETRY,
    }
    if is_word:
        result["optionImages"] = [item["image"] for item in values]
    return result


def build_lesson(item, group, template, old_rows):
    lesson = copy.deepcopy(template)
    lesson.update(id=item["id"], title=f"درس حرف {item['article']}")
    lesson["publication"] = {"status": "pending", "mediaQaPassed": False}
    scenes = {scene["id"]: scene for scene in lesson["scenes"]}
    text = narration(item)
    prior = group[:group.index(item)]
    # These are review knowledge dependencies, not development-access locks.
    if not prior:
        lesson["scenes"] = [s for s in lesson["scenes"] if s["type"] != "review"]
    else:
        review = scenes["prior_review_1"]
        known = old_rows + [x for x in LETTERS[:LETTERS.index(item)]]
        review["data"].update(
            priorLessonIds=[p["id"] for p in prior],
            questions=[question(p, [x for x in known if x["id"] != p["id"]][:3], kind)
                       for p in prior for kind in ("letter", "word")],
            successAudio=SUCCESS, retryAudio=RETRY,
        )
        # reviewQuestionOrder picks one kind per previous letter and shuffles.
        review["data"]["questionSelection"] = "runtime-disjoint-half-letter-half-word"

    for scene_id, key in (("welcome_1", "welcome"), ("nasheed_1", "nasheed_intro"),
                          ("pronounce_1", "pronounce_intro"), ("write_free_1", "free_intro"),
                          ("success_1", "closing")):
        bind_line(scenes[scene_id]["lines"][0], item, key, text[key])
    scenes["nasheed_1"]["data"] = {
        "mediaType": "audio", "label": f"أنشودة حرف {item['article']}",
        "mediaStatus": "not-provided",
    }
    explanation = scenes["explain_1"]
    for index, line in enumerate(explanation["lines"], 1):
        bind_line(line, item, f"explain_{index}", text[f"explain_{index}"])
    explanation["data"].update(
        letter=item["letter"], letterName=item["spoken"],
        letterAudio=audio(item, "explain_1"),
        example={"word": item["word"], "imageAsset": item["image"],
                 "highlightPrefix": item["letter"]},
    )
    scenes["pronounce_1"]["data"].update(
        letter=item["letter"], spokenLetter=item["spoken"], expected=item["spoken"],
        retryAudio=RETRY, letterAudio=audio(item, "tap_repeat_3"),
        letterTapAudio=audio(item, "tap_repeat_3"),
    )
    guided = scenes["write_guided_1"]
    for line, key in zip(guided["lines"], ("writing_demo", "writing_try")):
        bind_line(line, item, key, text[key])
    guided["data"].update(
        letter=item["letter"], lessonId=item["id"],
        traceTemplateId=item["traceTemplateId"], againAudio=audio(item, "writing_try"),
    )
    guided["data"].pop("demoPassDurationMs", None)
    free = scenes["write_free_1"]
    free["data"].update(letter=item["letter"], lessonId=item["id"],
                        traceTemplateId=item["traceTemplateId"])
    # The inherited renderer/learning-track policy controls repeats and skipping.
    # Current experimental user requirement permits every section to be skipped.
    for scene in lesson["scenes"]:
        scene["canSkip"] = True
    choices = [candidate for candidate in group if candidate != item]
    scenes["assessment_1"]["data"].update(
        retryAudio=RETRY, successAudio=SUCCESS,
        secondAudio=audio(item, "assessment_word"), questionAfterIntro=True,
        questions=[question(item, choices, kind) for kind in ("letter", "word")],
    )
    return lesson


def checkpoint_row(item):
    return {
        "id": item["id"], "letter": item["letter"], "word": item["word"],
        "image": item["image"], "letterAudio": audio(item, "assessment_letter"),
        "wordAudio": audio(item, "assessment_word"), "expected": item["spoken"],
        "pronunciationRetryAudio": RETRY, "traceTemplateId": item["traceTemplateId"],
        "freeAudio": audio(item, "free_intro"),
    }


def build_checkpoint(number, template, old_rows):
    checkpoint = copy.deepcopy(template)
    ordinal = {3: "الثالث", 4: "الرابع", 5: "الخامس"}[number]
    checkpoint.update(id=f"checkpoint_group_{number}", title=f"الاختبار المرحلي {ordinal}")
    checkpoint["publication"] = {"status": "pending", "mediaQaPassed": False}
    checkpoint["mastery"]["requiredSceneIds"] = [f"checkpoint_{number}"]
    scene = next(s for s in checkpoint["scenes"] if s["type"] == "checkpoint")
    scene.update(id=f"checkpoint_{number}", title=checkpoint["title"])
    scene["data"].update(
        standardizedFlow=True, recognitionCount=6, dragMatchCount=8, pronunciationCount=4,
        writingLetterIds=[item["id"] for item in LETTERS if item["group"] == number],
        letters=copy.deepcopy(old_rows) + [checkpoint_row(item) for item in LETTERS if item["group"] <= number],
        tasks=[], wrongAudio=RETRY,
    )
    # Intro and mastery congratulate no specific group number or letter: reuse.
    for child in checkpoint["scenes"]:
        child["canSkip"] = True
    return checkpoint


def make_pack(item, group, checklist):
    return {
        "id": item["id"], "version": 1, "title": f"حرف {item['name']}",
        "letter": item["letter"], "stageId": "letters_fatha", "status": "pending",
        "priorLessonIds": [x["id"] for x in group[:group.index(item)]],
        "reviewScope": "level", "lessonAsset": f"assets/content/lesson_{item['id']}.json",
        "audioFolder": f"assets/audio/{item['id']}/", "traceTemplateIds": [item["traceTemplateId"]],
        "exampleImages": [item["image"]], "reviewChecklist": checklist,
    }


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)


def build_bundle():
    base = read("assets/content/lesson_seen.json")
    dal = read("assets/content/lesson_dal.json")
    if any(s["type"] == "review" for s in dal["scenes"]):
        raise ValueError("The current first-letter template unexpectedly has prereview")
    checkpoint_base = read("assets/content/lesson_checkpoint_group_2.json")
    old_rows = next(s for s in checkpoint_base["scenes"] if s["type"] == "checkpoint")["data"]["letters"]
    checklist = read("assets/content/lesson_packs.json")["packs"][0]["reviewChecklist"]
    files, packs, levels = {}, [], []
    for number in (3, 4, 5):
        group = [item for item in LETTERS if item["group"] == number]
        for item in group:
            files[f"assets/content/lesson_{item['id']}.json"] = build_lesson(item, group, base, old_rows)
            packs.append(make_pack(item, group, checklist))
        checkpoint = build_checkpoint(number, checkpoint_base, old_rows)
        files[f"assets/content/lesson_checkpoint_group_{number}.json"] = checkpoint
        all_rows = next(s for s in checkpoint["scenes"] if s["type"] == "checkpoint")["data"]["letters"]
        packs.append({
            "id": checkpoint["id"], "title": checkpoint["title"], "version": 1,
            "kind": "checkpoint", "stageId": "letters_fatha", "status": "pending",
            "priorLessonIds": [row["id"] for row in all_rows], "reviewScope": "cumulative",
            "lessonAsset": f"assets/content/lesson_checkpoint_group_{number}.json",
            "audioFolder": "assets/audio/checkpoint_2/",
            "traceTemplateIds": [item["traceTemplateId"] for item in group],
            "exampleImages": [row["image"] for row in all_rows], "reviewChecklist": checklist,
        })
        packs.append({
            "id": f"reading_group_{number}", "version": 1, "kind": "reading",
            "title": "قراءة حرفين وثلاثة" if number == 5 else "قراءة حرفين معًا",
            "stageId": "letters_fatha", "status": "pending",
            "lessonAsset": f"assets/content/lesson_reading_group_{number}.json",
            "audioFolder": "assets/audio/reading/", "traceTemplateIds": [], "exampleImages": [],
            "priorLessonIds": [item["id"] for item in group], "reviewScope": "level",
            "reviewChecklist": checklist,
        })
        levels.append({
            "id": f"group_{number}", "title": f"المجموعة {number}",
            "lessons": [
                {"lessonId": item["id"], "title": f"حرف {item['name']}",
                 "subtitle": f"{item['letter']} — {item['word']}", "letter": item["letter"]}
                for item in group
            ] + [{"lessonId": checkpoint["id"], "title": checkpoint["title"],
                  "subtitle": "مراجعة تراكمية لجميع الحروف السابقة"},
                 {"lessonId": f"reading_group_{number}",
                  "title": "قراءة حرفين وثلاثة" if number == 5 else "قراءة حرفين معًا",
                  "subtitle": "اقرؤوا الحروف معًا"}],
        })
    clips = [
        {"letterId": item["id"], "key": key, "asset": audio(item, key), "text": text,
         "status": "not-generated", "listenedEntirely": False,
         "independentTranscript": None, "transcriptChecked": False,
         "pronunciationChecked": False, "allRepetitionsChecked": False,
         "sha256": None, "durationSec": None, "bytes": None,
         "animationTimingChecked": False}
        for item in LETTERS for key, text in narration(item).items()
    ]
    new_audio = {clip["asset"] for clip in clips}
    referenced = set(strings(files))
    reused = sorted(p for p in referenced if p.endswith(".mp3") and p not in new_audio)
    files["NARRATION_V60_PENDING.json"] = {
        "status": "pending-not-published", "provider": "ElevenLabs",
        "voiceName": "Laloosh - Upbeat Arabic Reels Voice", "voiceId": "zAHOVUiYXuxggpSljiCQ",
        "modelId": "eleven_v3", "generationsCount": 1, "gapSeconds": 1.5,
        "generationPolicy": "sequential; retry proven failures only; never duplicate in-flight or successful requests",
        "additionalVoiceSettings": {}, "clips": clips, "reusedAudio": reused,
    }
    files["MEDIA_REQUIREMENTS.json"] = {
        "status": "pending", "audio": [clip["asset"] for clip in clips],
        "images": [{"asset": item["image"], "letterId": item["id"], "word": item["word"],
                    "concept": item["imageConcept"], "status": "not-generated",
                    "requires": ["matching-approved-3d-style", "true-alpha", "correct-word", "phone-fit"]}
                   for item in LETTERS],
        "traces": [{"id": item["traceTemplateId"], "letter": item["letter"],
                    "status": "pending-reference-audit", "reference": "حروف.pdf",
                    "requires": ["exact-pdf-glyph", "dots-match-reference", "centerline-contained",
                                 "complete-fill", "stroke-order", "writing-narration-match"]}
                   for item in LETTERS],
        "nasheed": "No new songs were supplied; none are fabricated or copied from another letter.",
    }
    packs.insert(0, {
        "id": "reading_group_2", "version": 1, "kind": "reading", "title": "قراءة حرفين معًا",
        "stageId": "letters_fatha", "status": "pending",
        "lessonAsset": "assets/content/lesson_reading_group_2.json", "audioFolder": "assets/audio/reading/",
        "traceTemplateIds": [], "exampleImages": [], "priorLessonIds": ["dal", "dhal", "raa", "zay", "seen"],
        "reviewScope": "level", "reviewChecklist": checklist,
    })
    files["LESSON_PACKS_ADDITIONS.json"] = {"schemaVersion": 1, "packs": packs}
    files["PROGRAM_LEVELS_ADDITIONS.json"] = {
        "programId": "arabic_foundation", "stageId": "letters_fatha", "levels": levels,
        "existingLevelInsertions": [{
            "levelId": "group_2", "afterLessonId": "checkpoint_group_2",
            "lesson": {"lessonId": "reading_group_2", "title": "قراءة حرفين معًا", "subtitle": "اقرؤوا الحرفين معًا"},
        }],
    }
    files["AUTHORING_PROVENANCE.json"] = {
        "status": "source-data-authored-media-not-verified", "activeProjectModified": False,
        "templates": [{"path": path, "sha256": hashlib.sha256((ROOT / path).read_bytes()).hexdigest()}
                      for path in SOURCE_FILES],
        "letters": LETTERS,
        "releaseBlockers": ["new audio generation and complete audible/transcript QA",
                            "new image generation and semantic/transparency QA",
                            "PDF trace audit and writing animation QA",
                            "measured audio durations and synchronized farewell events",
                            "reading-test integration and learning-track regression tests",
                            "full content/voice/phone-layout tests before IPA"],
    }
    return files


def validate_bundle(files):
    errors = []
    clips = files["NARRATION_V60_PENDING.json"]["clips"]
    assets = {clip["asset"] for clip in clips}
    if len(assets) != len(clips):
        errors.append("Duplicated generation asset")
    for item in LETTERS:
        lesson = files[f"assets/content/lesson_{item['id']}.json"]
        prior = [x for x in LETTERS if x["group"] == item["group"] and LETTERS.index(x) < LETTERS.index(item)]
        reviews = [s for s in lesson["scenes"] if s["type"] == "review"]
        if bool(prior) != bool(reviews):
            errors.append(f"{item['id']}: first-letter review mismatch")
        for review in reviews:
            actual = {(q["reviewLessonId"], q["kind"]) for q in review["data"]["questions"]}
            expected = {(p["id"], kind) for p in prior for kind in ("letter", "word")}
            if actual != expected:
                errors.append(f"{item['id']}: incomplete/foreign review scope")
        for scene in lesson["scenes"]:
            for line in scene["lines"]:
                if line["audio"] in assets and "durationSec" in line:
                    errors.append(f"{item['id']}: unmeasured duration inherited")
                if line["audio"].startswith("assets/audio/seen/"):
                    errors.append(f"{item['id']}: wrong-letter template audio leaked")
            for q in scene["data"].get("questions", []):
                if len(set(q["options"])) != len(q["options"]) or q.get("showPrompt"):
                    errors.append(f"{item['id']}: duplicate choices or revealed question")
        if not item["word"].startswith(item["letter"]):
            errors.append(f"{item['id']}: word is missing initial fatha")
        for key, text in narration(item).items():
            for mention in re.findall(r"(?<!\w)(?:لحرف|حرف)\s+(\S+)", text):
                if not mention.startswith("ال") and not mention.startswith("جميل"):
                    errors.append(f"{item['id']}/{key}: missing definite article")
            if "همم" in text or "فتحة" in text:
                errors.append(f"{item['id']}/{key}: forbidden narration")
            if item["spoken"] + "ء" in text:
                errors.append(f"{item['id']}/{key}: invented final hamza")
        if narration(item)["tap_repeat_3"] != "، ".join([item["spoken"]] * 3) + ".":
            errors.append(f"{item['id']}: tap clip must contain exactly three phonemes")
    for number, count in ((3, 18), (4, 24), (5, 28)):
        checkpoint = files[f"assets/content/lesson_checkpoint_group_{number}.json"]
        data = next(s["data"] for s in checkpoint["scenes"] if s["type"] == "checkpoint")
        ids = [row["id"] for row in data["letters"]]
        if len(ids) != count or len(set(ids)) != count:
            errors.append(f"checkpoint {number}: wrong cumulative letter count")
        if data["writingLetterIds"] != [item["id"] for item in LETTERS if item["group"] == number]:
            errors.append(f"checkpoint {number}: free-writing scope differs from current group")
    return errors


def narration_markdown(manifest):
    rows = ["# نصوص الحروف الجديدة — مسودة v60 للمراجعة", "",
            "هذه النصوص لم تُولّد أو تُعتمد صوتيًا بعد. لا يجوز البناء منها قبل اجتياز مراجعة الصوت والصورة والمسار.", "",
            "الصوت: Laloosh، Eleven v3، نسخة واحدة، بفاصل 1.5 ثانية. لا إعدادات سرعة أو طبقة مخترعة.", "",
            "داخل الجملة: حرف الشَا ونظائره؛ مع الكلمة أو التكرار: شَا بلا أل وبلا همزة نهائية زائدة.", "",
            "الكلمة المصححة للعَ: عَلَمٌ (راية)، وللمَ: مَوْز (الفاكهة). كل الكلمات تبدأ بفتحة.", ""]
    for item in LETTERS:
        rows.extend([f"## حرف {item['name']} — {item['letter']} — {item['word']}", ""])
        for index, clip in enumerate((c for c in manifest["clips"] if c["letterId"] == item["id"]), 1):
            rows.extend([f"### {index}. {clip['key']}", "", clip["text"], "",
                         f"الملف المنتظر: `{clip['asset']}`", ""])
    rows.extend(["## أصوات مشتركة يعاد استعمالها دون طلب توليد", ""])
    rows.extend(f"- `{path}`" for path in manifest["reusedAudio"])
    return "\n".join(rows) + "\n"


README = """# حزمة إعداد الحروف v60 — غير مدمجة وغير صالحة للنشر بعد

تضم 16 درسًا بنفس قالب الدروس الحالي، وثلاثة اختبارات مرحلية تراكمية.

- الثالثة: شَ صَ ضَ طَ ظَ عَ؛ الاختبار يغطي الألف إلى العين (18 حرفًا).
- الرابعة: غَ فَ قَ كَ لَ مَ؛ الاختبار يغطي الألف إلى الميم (24 حرفًا).
- الخامسة: نَ هَ وَ يَ؛ الاختبار يغطي جميع الحروف (28 حرفًا).
- مراجعة كل درس محصورة في حروف مجموعته السابقة فقط. أول حرف بلا مراجعة.
- لكل حرف سابق مرشح حرف ومرشح كلمة؛ المحرك الحالي يختار واحدًا منهما فقط، ويقسم الحروف عشوائيًا بين النوعين. لا تعرض جميع المرشحات دفعة واحدة.
- كل اختبار مرحلي: 6 تعرّف، 8 سحب، 4 نطق، وكتابة حرة لحروف المجموعة الحالية فقط؛ لا كتابة بالدليل في الاختبار.
- تبقى أوضاع القراءة/الكتابة وتخطي الفقرات التجريبي من مسؤولية محرك المسارات الحالي، دون اختراع مسار جديد.

الكلمات المصححة: **عَ — عَلَمٌ** (راية لا عالم)، **مَ — مَوْز** (الفاكهة).
الفاء: **فَتْح** كما اختار المستخدم؛ تحتاج الصورة مراجعة معناها قبل الاعتماد.

## الملفات

`assets/content` هنا مجلد داخل الحزمة المعلقة، وليس أصول التطبيق النشطة.
`LESSON_PACKS_ADDITIONS.json` و`PROGRAM_LEVELS_ADDITIONS.json` إضافات مقترحة فقط، لا بد من دمجها بحذر بعد اختبارات القراءة التي يعدها العمل الموازي.
`NARRATION_V60_PENDING.json` طلبات الصوت ونقاط التحقق. كل حالة Not generated؛ لا بصمات أو مدد مختلقة.
`NARRATION-AR.md` نصوص التسجيل كاملة للمراجعة. `MEDIA_REQUIREMENTS.json` قائمة الصور ومسارات الحروف المطلوبة.

## قبل الدمج والبناء

1. مراجعة جميع النصوص وتطابق وصف الكتابة مع مرجع PDF. القالب ثابت؛ الوصف الخاص بالمسار يحتاج تدقيقًا قبل التوليد.
2. توليد المقاطع بالتتابع بالإعدادات المعتمدة فقط، وإعادة الفاشل الحقيقي دون تكرار الناجح أو الجاري.
3. استماع كامل، وتفريغ مستقل، ومقارنة النص وكل تكرار؛ أل داخل الجملة، وصوت مجرد بلا أل أو همزة زائدة. تسجيل الملف وSHA-256 والمدة والتفريغ وحالة التحقق.
4. لا يُعتمد صوت لمجرد نجاح الطلب. يُضبط توقيت الحركات والوداع بعد قياس الصوت؛ لم تُنسخ مدد الحروف القديمة.
5. تدقيق صور ثلاثية الأبعاد متسقة وشفافة بحق، ومسارات ونقاط مطابقة لمرجع المستخدم؛ لا رسوم تقريبية أو صوت حرف آخر.
6. لا توجد أناشيد جديدة مرفقة؛ لا تنسب أنشودة حرف سابق إلى حرف جديد.
7. دمج اختبارات قراءة حرفين/ثلاثة من صور المستخدم، ثم اختبار المسارات الثلاثة والواجهة والمحتوى والصوتيات قبل إنشاء IPA.

لم تُعدّل `pubspec.yaml` أو برامج/حزم الدروس النشطة. لا تتغير حالة pending إلى available قبل التحقق الفعلي.

## إعادة الإنتاج والتحقق البنيوي فقط

```
python -m unittest discover -s tool -p test_build_v60_content.py
python tool/build_v60_content.py
python tool/build_v60_content.py --check
python -m unittest discover -s tool -p test_validate_v60_readiness.py
python tool/validate_v60_readiness.py
```

نجاح التحقق البنيوي لا يعني توليد الملفات الصوتية ولا سماعها ولا صلاحية الإصدار للنشر.
بوابة الجاهزية للقراءة فقط: تتوقع 256 تعليق حرف وتعليقي قراءة، مع ملف `READING_AUDIO_QA.json` منفصل، وتفشل ما دام الاستماع الكامل أو الفحص المستقل أو أحد الأصول ناقصًا. لا تضبط أي علامة تحقق بنفسها ولا تبدأ البناء.
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate current authored files without writing")
    args = parser.parse_args()
    files = build_bundle()
    errors = validate_bundle(files)
    if errors:
        raise SystemExit("\n".join(errors))
    rendered = {path: json.dumps(value, ensure_ascii=False, indent=2) + "\n" for path, value in files.items()}
    rendered["NARRATION-AR.md"] = narration_markdown(files["NARRATION_V60_PENDING.json"])
    rendered["README-AR.md"] = README
    if args.check:
        mismatches = [name for name, expected in rendered.items()
                      if not (DESTINATION / name).exists()
                      or (DESTINATION / name).read_text(encoding="utf-8") != expected]
        if mismatches:
            raise SystemExit("Pending files differ/missing: " + ", ".join(mismatches))
    else:
        for name, contents in rendered.items():
            output = DESTINATION / name
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(contents, encoding="utf-8")
    print(f"Pending-only v60: 16 lessons, 3 checkpoints, {len(files['NARRATION_V60_PENDING.json']['clips'])} ungenerated clips; structural checks passed. No release/media QA claimed.")


if __name__ == "__main__":
    main()
