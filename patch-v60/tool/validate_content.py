"""Validate versioned lesson packages before tests/build. No network or writes."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENES = {'review', 'welcome', 'nasheed', 'explanation', 'pronunciation', 'reading',
          'guidedWriting', 'freeWriting', 'imageWordActivity', 'multipleChoice',
          'assessment', 'checkpoint', 'success'}

def validate(root=ROOT):
    errors = []
    def require(condition, message):
        if not condition:
            errors.append(message)
    def asset(path):
        resolved = (root / path).resolve()
        require(resolved.is_relative_to(root.resolve()) and resolved.is_file(), f'Missing/unsafe asset: {path}')
    catalog = json.loads((root / 'assets/content/lesson_packs.json').read_text(encoding='utf-8'))
    require(catalog.get('schemaVersion') == 1, 'Unsupported catalog schema')
    programs = json.loads((root / 'assets/content/programs.json').read_text(encoding='utf-8'))
    stage_lessons = {stage['id']: [lesson['lessonId'] for level in stage['levels'] for lesson in level['lessons']]
                     for program in programs for stage in program['stages']}
    level_lessons = {lesson['lessonId']: [item['lessonId'] for item in level['lessons']]
                     for program in programs for stage in program['stages']
                     for level in stage['levels'] for lesson in level['lessons']}
    pack_by_id = {p['id']: p for p in catalog['packs']}
    ids = set()
    for pack in catalog['packs']:
        pid = pack['id']
        require(pid not in ids, f'Duplicate package {pid}')
        ids.add(pid)
        require(pack.get('version', 0) > 0, f'{pid}: missing version')
        require(bool(pack.get('reviewChecklist')), f'{pid}: missing review checklist')
        asset(pack['lessonAsset'])
        path = root / pack['lessonAsset']
        if not path.is_file():
            continue
        lesson = json.loads(path.read_text(encoding='utf-8'))
        require(lesson['id'] == pid, f'{pid}: mismatched lesson id')
        scenes = lesson.get('scenes', [])
        stage_id = pack.get('stageId')
        if stage_id:
            ordered = stage_lessons.get(stage_id, [])
            require(pid in ordered, f'{pid}: missing from curriculum stage')
            prior_order = level_lessons.get(pid, ordered) if pack.get('reviewScope') == 'level' else ordered
            expected_prior = ([lesson_id for lesson_id in prior_order[:prior_order.index(pid)]
                               if pack_by_id.get(lesson_id, {}).get('kind') not in {'checkpoint', 'reading'}]
                              if pid in prior_order else [])
            require(pack.get('priorLessonIds') == expected_prior, f'{pid}: incomplete cumulative review')
            if pack.get('kind') not in {'checkpoint', 'reading'}:
                reviews = [s for s in scenes if s['type'] == 'review']
                questions = [q for s in reviews for q in s.get('data', {}).get('questions', [])]
                letter_questions = [q for q in questions if q.get('kind','letter') == 'letter']
                word_questions = [q for q in questions if q.get('kind') == 'word']
                if pack.get('reviewScope') == 'level':
                    reviewed = [q.get('reviewLessonId') for q in questions]
                    pooled = bool(reviews) and all(s.get('data', {}).get('questionSelection') ==
                        'runtime-disjoint-half-letter-half-word' for s in reviews)
                    if pooled:
                        require([q.get('reviewLessonId') for q in letter_questions] == expected_prior
                                and [q.get('reviewLessonId') for q in word_questions] == expected_prior,
                                f'{pid}: pooled review must offer exactly one letter and word per prior letter')
                    else:
                        require(reviewed == expected_prior,
                                f'{pid}: package review must cover each previous package letter once')
                    require(not reviews or all(s.get('canSkip') is True for s in reviews),
                            f'{pid}: package review must be skippable')
                elif len(expected_prior) > 6:
                    reviewed = [q.get('reviewLessonId') for q in questions]
                    require(len(letter_questions) == 3 and len(word_questions) == 3,
                            f'{pid}: cumulative review must contain three letters and three words')
                    require(len(reviewed) == 6 and len(set(reviewed)) == 6 and
                            set(reviewed).issubset(expected_prior),
                            f'{pid}: cumulative review must use six distinct prior letters')
                else:
                    require([q.get('reviewLessonId') for q in letter_questions] == expected_prior, f'{pid}: review questions do not cover previous letters')
                    if word_questions:
                        require([q.get('reviewLessonId') for q in word_questions] == expected_prior, f'{pid}: word review does not cover prior letters')
                for q in questions:
                    prior = pack_by_id.get(q.get('reviewLessonId'))
                    index = q.get('correctIndex', -1)
                    if prior and 0 <= index < len(q.get('options', [])):
                        if q.get('kind') == 'word':
                            require(q['options'][index].startswith(prior['letter']), f'{pid}: review word does not start with prior letter')
                        else:
                            require(q['options'][index] == prior['letter'], f'{pid}: review answer is not the prior letter')

        scene_ids = [s['id'] for s in scenes]
        require(len(scene_ids) == len(set(scene_ids)), f'{pid}: duplicate scene id')
        for required in lesson.get('mastery', {}).get('requiredSceneIds', []):
            require(required in scene_ids, f'{pid}: required scene missing: {required}')
        for scene in scenes:
            label = f"{pid}/{scene['id']}"
            require(scene['type'] in SCENES, f'{label}: unknown scene type')
            data = scene.get('data', {})
            if scene['type'] in {'guidedWriting', 'freeWriting'}:
                require(data.get('traceTemplateId') in pack['traceTemplateIds'] or bool(data.get('strokes')), f'{label}: writing geometry missing')
            for line in scene.get('lines', []):
                require(bool(line.get('male')) and bool(line.get('female')), f'{label}: missing script text')
                if line.get('audio'):
                    asset(line['audio'])
            for question in data.get('questions', []):
                options = question.get('options', [])
                require(len(options) >= 2, f'{label}: insufficient choices')
                require(0 <= question.get('correctIndex', -1) < len(options), f'{label}: invalid answer index')
                images = question.get('optionImages', [])
                require(not images or len(images) == len(options), f'{label}: images do not align with choices')
            for task in data.get('tasks', []):
                task_label = f"{label}/{task.get('id', 'unknown')}"
                options = task.get('options', [])
                if options:
                    require(len(options) >= 2, f'{task_label}: insufficient choices')
                    require(0 <= task.get('correctIndex', -1) < len(options),
                            f'{task_label}: invalid answer index')
                images = task.get('optionImages', [])
                require(not images or len(images) == len(options),
                        f'{task_label}: images do not align with choices')
                if task.get('type') in {'guided', 'free'}:
                    require(task.get('traceTemplateId') in pack['traceTemplateIds'],
                            f'{task_label}: checkpoint writing geometry missing')
                if task.get('type') == 'match':
                    require(len(task.get('pairs', [])) >= 2,
                            f'{task_label}: insufficient matching pairs')
            def visit(value):
                if isinstance(value, dict):
                    for child in value.values(): visit(child)
                elif isinstance(value, list):
                    for child in value: visit(child)
                elif isinstance(value, str) and value.startswith('assets/'):
                    asset(value)
            visit(data)
        for image in pack.get('exampleImages', []): asset(image)
    return errors

if __name__ == '__main__':
    failures = validate()
    if failures:
        raise SystemExit('\n'.join(failures))
    print('Lesson package validation passed: assets, scripts, scene ids, tracing declarations and answer mapping.')
