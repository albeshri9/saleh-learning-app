"""Rebuild group two by cloning the approved Khaa lesson structure exactly.

Only the letter, example word, image, trace template and the shape-specific
writing sentence change.  This deliberately avoids introducing a new lesson
script or a new interaction pattern.
"""
from __future__ import annotations

import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT.parent / "video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"


LETTERS = [
    {
        "id": "dal", "letter": "دَ", "spoken": "دَا", "article": "الدَا",
        "word": "دَجَاجَة", "image": "chicken_v54.png",
        "template": "dal_fatha_pdf_v1",
        "writing": "نبدأ من أعلى اليمين، ونتبع المسار بانحناءة هادئة حتى نهاية الحرف.",
    },
    {
        "id": "dhal", "letter": "ذَ", "spoken": "ذَا", "article": "الذَا",
        "word": "ذَيْل", "image": "tail_v54.png",
        "template": "dhal_fatha_pdf_v1",
        "writing": "نبدأ من أعلى اليمين، ونتبع المسار بانحناءة هادئة حتى نهاية الحرف، ثم نضع نقطة فوق الحرف.",
    },
    {
        "id": "raa", "letter": "رَ", "spoken": "رَا", "article": "الرَا",
        "word": "رَجُل", "image": "man_v54.png",
        "template": "raa_fatha_pdf_v1",
        "writing": "نبدأ من أعلى اليمين، ونتبع المسار بانحناءة إلى أسفل اليسار حتى نهاية الحرف.",
    },
    {
        "id": "zay", "letter": "زَ", "spoken": "زَا", "article": "الزَا",
        "word": "زَرَافَة", "image": "giraffe_v54.png",
        "template": "zay_fatha_pdf_v1",
        "writing": "نبدأ من أعلى اليمين، ونتبع المسار بانحناءة إلى أسفل اليسار حتى نهاية الحرف، ثم نضع نقطة فوق الحرف.",
    },
    {
        "id": "seen", "letter": "سَ", "spoken": "سَا", "article": "السَا",
        "word": "سَاعَة", "image": "clock_v54.png",
        "template": "seen_fatha_pdf_v1",
        "writing": "نبدأ من اليمين، ونتبع تعرجات الحرف، ثم نكمل الانحناءة إلى اليسار حتى نهاية الحرف.",
    },
]


def read(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def write(relative, data):
    (ROOT / relative).write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def audio(item, name):
    return f"assets/audio/{item['id']}/{name}.mp3"


def duration(relative, fallback):
    path = ROOT / relative
    if not path.exists() or not FFMPEG.exists():
        return fallback
    result = subprocess.run(
        [str(FFMPEG), "-hide_banner", "-i", str(path)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    ).stderr
    match = re.search(r"Duration: (\d+):(\d+):([\d.]+)", result)
    if not match:
        return fallback
    hours, minutes, seconds = map(float, match.groups())
    return round(hours * 3600 + minutes * 60 + seconds, 2)


def set_line(line, text, asset):
    line["male"] = text
    line["female"] = text
    line["audio"] = asset
    line["durationSec"] = duration(asset, line.get("durationSec", 3.0))


def narration(item):
    article = item["article"]
    spoken = item["spoken"]
    word = item["word"]
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
        "writing_demo": f"انظروا يا أصدقائي كيف نكتب حرف {article}. {item['writing']}",
        "writing_try": f"هيا يا أصدقائي، اكتبوا حرف {article}. ضعوا إصبعكم على النقطة الخضراء، واتبعوا مسار الحرف حتى النهاية. {spoken}، {spoken}.",
        "free_intro": f"هيا يا أصدقائي، هل تذكرون كيفية كتابة حرف {article}؟ قوموا بكتابة حرف {article} الآن.",
        "assessment_letter": f"أين حرف {spoken}؟ اضغطوا على حرف {spoken}.",
        "assessment_word": f"أين الصورة التي تبدأ بحرف {spoken}؟ اختاروا الصورة الصحيحة.",
        "closing": f"أحسنتم يا أبطال. الحمد لله، لقد تعرفنا هذا اليوم على حرف {article}. {spoken}، {word}. إلى اللقاء يا أصدقائي.",
    }


def build_review(scene, prior):
    scene["canSkip"] = True
    questions = []
    for index, target in enumerate(prior):
        use_word = index % 2 == 1
        alternatives = [item for item in LETTERS if item["id"] != target["id"]][:3]
        if use_word:
            question = {
                "kind": "word", "reviewLessonId": target["id"],
                "showPrompt": False,
                "prompt": f"أين الصورة التي تبدأ بحرف {target['spoken']}؟",
                "options": [target["word"], *[item["word"] for item in alternatives[:2]]],
                "optionImages": [
                    f"assets/images/assessment/{target['image']}",
                    *[f"assets/images/assessment/{item['image']}" for item in alternatives[:2]],
                ],
                "correctIndex": 0,
                "audio": audio(target, "assessment_word"),
            }
        else:
            question = {
                "kind": "letter", "reviewLessonId": target["id"],
                "showPrompt": False, "prompt": f"أين حرف {target['spoken']}؟",
                "options": [target["letter"], *[item["letter"] for item in alternatives]],
                "correctIndex": 0,
                "audio": audio(target, "assessment_letter"),
            }
        question.update(
            successAudio="assets/audio/taa/assessment_success.mp3",
            retryAudio="assets/audio/taa/assessment_retry.mp3",
        )
        questions.append(question)
    scene["data"]["priorLessonIds"] = [item["id"] for item in prior]
    scene["data"]["questions"] = questions


def build_lesson(item, prior):
    lesson = copy.deepcopy(read("assets/content/lesson_khaa.json"))
    lesson["id"] = item["id"]
    lesson["title"] = f"درس حرف {item['letter']}"
    scenes = {scene["id"]: scene for scene in lesson["scenes"]}
    text = narration(item)

    set_line(scenes["welcome_1"]["lines"][0], text["welcome"], audio(item, "welcome"))

    if not prior:
        lesson["scenes"] = [
            scene for scene in lesson["scenes"] if scene["id"] != "prior_review_1"
        ]
    else:
        build_review(scenes["prior_review_1"], prior)

    set_line(scenes["nasheed_1"]["lines"][0], text["nasheed_intro"], audio(item, "nasheed_intro"))
    scenes["nasheed_1"]["data"]["label"] = f"أنشودة حرف {item['letter']}"

    explanation = scenes["explain_1"]
    for index, line in enumerate(explanation["lines"], start=1):
        set_line(line, text[f"explain_{index}"], audio(item, f"explain_{index}"))
    explanation["data"].update(
        letter=item["letter"], letterName=item["spoken"],
        letterAudio=audio(item, "explain_1"),
        example={
            "word": item["word"],
            "imageAsset": f"assets/images/assessment/{item['image']}",
            "highlightPrefix": item["letter"],
        },
    )

    pronounce = scenes["pronounce_1"]
    set_line(pronounce["lines"][0], text["pronounce_intro"], audio(item, "pronounce_intro"))
    pronounce["data"].update(
        letter=item["letter"], spokenLetter=item["spoken"], expected=item["spoken"],
        letterAudio=audio(item, "explain_2"),
        retryAudio="assets/audio/checkpoint_1/retry_only_v51.mp3",
    )

    guided = scenes["write_guided_1"]
    set_line(guided["lines"][0], text["writing_demo"], audio(item, "writing_demo"))
    set_line(guided["lines"][1], text["writing_try"], audio(item, "writing_try"))
    guided["data"].update(
        letter=item["letter"], lessonId=item["id"],
        traceTemplateId=item["template"], againAudio=audio(item, "writing_try"),
        demoPassDurationMs=round(guided["lines"][0]["durationSec"] * 1000),
    )

    free = scenes["write_free_1"]
    set_line(free["lines"][0], text["free_intro"], audio(item, "free_intro"))
    free["data"].update(
        letter=item["letter"], lessonId=item["id"],
        traceTemplateId=item["template"],
    )

    assessment = scenes["assessment_1"]
    assessment["data"]["secondAudio"] = audio(item, "assessment_word")
    alternatives = [candidate for candidate in LETTERS if candidate["id"] != item["id"]]
    assessment["data"]["questions"] = [
        {
            "prompt": f"اضغط على حرف {item['letter']}", "showPrompt": False,
            "options": [item["letter"], *[candidate["letter"] for candidate in alternatives[:3]]],
            "correctIndex": 0, "audio": audio(item, "assessment_letter"),
        },
        {
            "prompt": f"ما الكلمة التي تبدأ بحرف {item['letter']}؟", "showPrompt": False,
            "options": [item["word"], *[candidate["word"] for candidate in alternatives[:2]]],
            "optionImages": [
                f"assets/images/assessment/{item['image']}",
                *[f"assets/images/assessment/{candidate['image']}" for candidate in alternatives[:2]],
            ],
            "correctIndex": 0, "audio": audio(item, "assessment_word"),
        },
    ]

    closing = scenes["success_1"]["lines"][0]
    set_line(closing, text["closing"], audio(item, "closing"))
    write(f"assets/content/lesson_{item['id']}.json", lesson)
    return text


def main():
    generated = {}
    for index, item in enumerate(LETTERS):
        generated[item["id"]] = build_lesson(item, LETTERS[:index])

    checkpoint = read("assets/content/lesson_checkpoint_group_2.json")
    checkpoint_scene = next(scene for scene in checkpoint["scenes"] if scene["type"] == "checkpoint")
    checkpoint_scene["data"]["letters"] = [
        {
            "id": item["id"], "letter": item["letter"], "word": item["word"],
            "image": f"assets/images/assessment/{item['image']}",
            "letterAudio": audio(item, "assessment_letter"),
            "wordAudio": audio(item, "assessment_word"),
            "expected": item["spoken"],
            "pronunciationRetryAudio": "assets/audio/checkpoint_1/retry_only_v51.mp3",
            "traceTemplateId": item["template"],
            "freeAudio": audio(item, "free_intro"),
        }
        for item in LETTERS
    ]
    write("assets/content/lesson_checkpoint_group_2.json", checkpoint)

    packs = read("assets/content/lesson_packs.json")
    by_id = {pack["id"]: pack for pack in packs["packs"]}
    for index, item in enumerate(LETTERS):
        pack = by_id[item["id"]]
        pack.update(
            title=f"حرف {item['spoken']}", letter=item["letter"],
            priorLessonIds=[previous["id"] for previous in LETTERS[:index]],
            status="available", lessonAsset=f"assets/content/lesson_{item['id']}.json",
            audioFolder=f"assets/audio/{item['id']}/",
            traceTemplateIds=[item["template"]],
            exampleImages=[f"assets/images/assessment/{item['image']}"],
            reviewScope="level",
        )
    by_id["checkpoint_group_2"]["status"] = "available"
    by_id["checkpoint_group_2"]["priorLessonIds"] = [item["id"] for item in LETTERS]
    by_id["checkpoint_group_2"]["reviewScope"] = "level"
    write("assets/content/lesson_packs.json", packs)

    programs = read("assets/content/programs.json")
    level = next(
        level for level in programs[0]["stages"][0]["levels"]
        if level["id"] == "group_2"
    )
    level["lessons"] = [
        {
            "lessonId": item["id"], "title": f"حرف {item['spoken']}",
            "subtitle": f"{item['letter']} — {item['word']}", "letter": item["letter"],
        }
        for item in LETTERS
    ] + [{
        "lessonId": "checkpoint_group_2", "title": "الاختبار المرحلي الثاني",
        "subtitle": "إتقان حروف المجموعة الثانية",
    }]
    write("assets/content/programs.json", programs)

    manifest = {
        "provider": "ElevenLabs", "voiceName": "Laloosh",
        "voiceId": "zAHOVUiYXuxggpSljiCQ", "modelId": "eleven_v3",
        "generationsCount": 1, "gapSeconds": 1.5,
        "clips": [
            {
                "letterId": item["id"], "key": key,
                "asset": audio(item, key), "text": generated[item["id"]][key],
            }
            for item in LETTERS for key in generated[item["id"]]
        ] + [{
            "letterId": "app", "key": "first_launch_welcome_v55",
            "asset": "assets/audio/first_launch_welcome_v55.mp3",
            "text": "أهلًا وسهلًا بكم في برنامج تَعلًَمْ مَعَ صالِحْ! هنا نقرأ الحروف والكلمات، ونتدرّب على الكتابة، ونلعب ألعابًا تعليمية ممتعة. اختاروا رحلتكم، وهيا نبدأ معًا.",
        }],
    }
    write("tool/v55_narration.json", manifest)
    audio_manifest = copy.deepcopy(manifest)
    for clip in audio_manifest["clips"]:
        path = ROOT / clip["asset"]
        if path.exists():
            clip["bytes"] = path.stat().st_size
            clip["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            clip["durationSec"] = duration(clip["asset"], 0)
    write("AUDIO_V55_MANIFEST.json", audio_manifest)
    print(f"v55 content built from the accepted Khaa template: {len(manifest['clips'])} clips.")


if __name__ == "__main__":
    main()
