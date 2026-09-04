"""Read-only, unprompted local ASR audit of generated v60 MP3 files.

An ASR difference is a review candidate, not a proven pronunciation defect.
An ASR match is not listening approval. No assets or approval flags are changed.
"""
import argparse
from difflib import SequenceMatcher
import hashlib
import json
from pathlib import Path
import re
import sys

from time_v60_farewells import ROOT, MODEL, LOCAL_DEPENDENCIES


def normalized_words(value):
    value = re.sub(r'[\u064b-\u065f\u0670\u0640]', '', value)
    value = value.translate(str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا'}))
    return re.findall(r'[\u0621-\u064a]+', value)


def comparison(expected, observed):
    wanted, actual = normalized_words(expected), normalized_words(observed)
    return {
        'normalizedTextMatches': wanted == actual,
        'wordSequenceSimilarity': round(SequenceMatcher(None, wanted, actual).ratio(), 4),
        'expectedWords': wanted,
        'observedWords': actual,
        'listenedEntirely': False,
        'pronunciationApproved': False,
    }


def cache_matches(cached, asset, digest, expected):
    return (cached.get('asset') == asset and cached.get('sha256') == digest
            and cached.get('expectedText') == expected
            and cached.get('method') == 'local-faster-whisper-small-unprompted'
            and isinstance(cached.get('transcript'), str))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--letter', action='append')
    parser.add_argument('--key', action='append')
    parser.add_argument('--existing-report', type=Path)
    args = parser.parse_args()
    pending = ROOT / 'pending_content/v60'
    manifest = json.loads((pending / 'NARRATION_V60_PENDING.json').read_text(encoding='utf-8-sig'))
    cached = {}
    if args.existing_report and args.existing_report.is_file():
        previous = json.loads(args.existing_report.read_text(encoding='utf-8-sig'))
        cached = {item['asset']: item for item in previous.get('clips', [])}
    if not MODEL.is_dir() or not LOCAL_DEPENDENCIES.is_dir():
        raise SystemExit('Cached Whisper model/dependencies missing; no download attempted.')
    sys.path.insert(0, str(LOCAL_DEPENDENCIES))
    from faster_whisper import WhisperModel
    model = None
    results = []
    for clip in manifest['clips']:
        if args.letter and clip['letterId'] not in args.letter:
            continue
        if args.key and clip['key'] not in args.key:
            continue
        path = pending / clip['asset']
        if not path.is_file():
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        old = cached.get(clip['asset'], {})
        if cache_matches(old, clip['asset'], digest, clip['text']):
            # Do not propagate any human-approval field from a cached ASR report.
            observed = old['transcript']
        else:
            if model is None:
                model = WhisperModel(str(MODEL), device='cpu', compute_type='int8', cpu_threads=4)
            segments, _ = model.transcribe(str(path), language='ar', beam_size=5,
                                            vad_filter=False, condition_on_previous_text=False)
            observed = ''.join(segment.text for segment in segments).strip()
        results.append({
            'letterId': clip['letterId'], 'key': clip['key'], 'asset': clip['asset'],
            'sha256': digest, 'expectedText': clip['text'], 'transcript': observed,
            'method': 'local-faster-whisper-small-unprompted',
            **comparison(clip['text'], observed),
        })
    print(json.dumps({'clips': results, 'count': len(results),
                      'reviewCandidates': sum(not item['normalizedTextMatches'] for item in results),
                      'auditoryApproval': False}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
