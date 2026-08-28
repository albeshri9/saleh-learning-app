"""Validate versioned lesson packages before tests/build. No network or writes."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENES = {'review', 'welcome', 'nasheed', 'explanation', 'pronunciation', 'reading',
          'guidedWriting', 'freeWriting', 'imageWordActivity', 'multipleChoice', 'assessment', 'success'}

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
