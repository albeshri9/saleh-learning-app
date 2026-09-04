"""Read-only local ASR word timings for farewell animation candidates.

Uses the already cached Whisper model without downloading anything. These
timings are machine estimates, NOT audible approval or a pronunciation test.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCAL_DEPENDENCIES = ROOT.parent / 'python-deps-whisper'
MODEL = ROOT.parent / 'whisper-models/models--Systran--faster-whisper-small/snapshots/536b0662742c02347bc0e980a01041f333bce120'


def normalize(value):
    return re.sub(r'[^\u0621-\u064A]', '', value).replace('إ', 'ا').replace('أ', 'ا')


def farewell_start(words):
    for index, word in enumerate(words):
        value = normalize(word['word'])
        if 'اللقاء' not in value:
            continue
        if index and normalize(words[index - 1]['word']) in ('الى', 'الي'):
            return words[index - 1]['start']
        return word['start']
    return None


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--letter', action='append')
    args = parser.parse_args()
    if not MODEL.is_dir() or not LOCAL_DEPENDENCIES.is_dir():
        raise SystemExit('Cached local Whisper dependencies/model missing; no download attempted.')
    sys.path.insert(0, str(LOCAL_DEPENDENCIES))
    from faster_whisper import WhisperModel
    model = WhisperModel(str(MODEL), device='cpu', compute_type='int8', cpu_threads=4)
    paths = sorted((ROOT / 'pending_content/v60/assets/audio').glob('*/closing_v60.mp3'))
    results = []
    for path in paths:
        if args.letter and path.parent.name not in args.letter:
            continue
        segments, info = model.transcribe(str(path), language='ar', word_timestamps=True,
                                          beam_size=3, vad_filter=False,
                                          condition_on_previous_text=False)
        words = []
        texts = []
        for segment in segments:
            texts.append(segment.text)
            words.extend({'word': word.word, 'start': word.start, 'end': word.end}
                         for word in (segment.words or []))
        results.append({'letterId': path.parent.name,
                        'asset': path.relative_to(ROOT / 'pending_content/v60').as_posix(),
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'transcript': ''.join(texts).strip(), 'words': words,
                        'farewellAtSecCandidate': farewell_start(words),
                        'listenedEntirely': False, 'method': 'local-faster-whisper-small-word-timestamps'})
    print(json.dumps({'timings': results, 'auditoryApproval': False}, ensure_ascii=False, indent=2))
