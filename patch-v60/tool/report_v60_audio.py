"""Read-only generated-audio audit; emits evidence, never approves listening.

Per-clip generation_records are the durable source of request/transcript IDs.
The returned manifest may be reviewed and applied separately with apply_patch.
No active application asset or manual QA flag is modified by this tool.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from validate_v60_readiness import PENDING, ROOT, find_ffmpeg, probe_mp3


def report(pending=PENDING, root=ROOT, decode=probe_mp3):
    pending = Path(pending)
    manifest = json.loads((pending / 'NARRATION_V60_PENDING.json').read_text(encoding='utf-8-sig'))
    executable = find_ffmpeg(Path(root))
    counts = Counter()
    letters = Counter()
    issues = []
    measured = []
    for source in manifest['clips']:
        record_path = pending / 'generation_records' / source['letterId'] / (source['key'] + '.json')
        if not record_path.is_file():
            counts['notDispatched'] += 1
            continue
        record = json.loads(record_path.read_text(encoding='utf-8-sig'))
        if record.get('text') != source['text'] or record.get('asset') != source['asset']:
            issues.append({'asset': source['asset'], 'issue': 'record/script mismatch'})
            continue
        counts['dispatched'] += 1
        path = pending / source['asset']
        if not path.is_file() or not path.stat().st_size:
            counts['filePending'] += 1
            continue
        observed_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        if record.get('sha256') and record['sha256'].lower() != observed_hash:
            issues.append({'asset': source['asset'], 'issue': 'file changed after generation'})
            continue
        duration, error = decode(path, executable)
        if error:
            issues.append({'asset': source['asset'], 'issue': str(error)})
            continue
        counts['decodedMp3'] += 1
        letters[source['letterId']] += 1
        source.update(record)
        source.update(sha256=observed_hash, bytes=path.stat().st_size, durationSec=duration)
        measured.append({key: source[key] for key in ('asset', 'sha256', 'bytes', 'durationSec')})
        # A generated file or exact transcript cannot set these manual flags.
        for flag in ('listenedEntirely', 'pronunciationChecked', 'allRepetitionsChecked', 'animationTimingChecked'):
            source[flag] = record.get(flag) is True
        if not all(source[flag] for flag in ('listenedEntirely', 'pronunciationChecked', 'allRepetitionsChecked')):
            counts['auditoryReviewPending'] += 1
        if source.get('independentTranscript'):
            counts['transcriptsCollected'] += 1
            counts['transcriptsMatched' if source.get('transcriptChecked') else 'transcriptDifferences'] += 1
        else:
            counts['transcriptsPending'] += 1
    manifest['status'] = 'generation-in-progress-awaiting-auditory-review'
    if counts['decodedMp3'] == len(manifest['clips']):
        manifest['status'] = 'generated-awaiting-auditory-review'
    return {'summary': {'required': len(manifest['clips']), **counts, 'byLetter': dict(letters),
                        'issues': issues, 'auditoryApprovalInferred': False},
            'manifest': manifest, 'metadata': measured}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', action='store_true')
    parser.add_argument('--metadata', action='store_true',
                        help='Emit measured file metadata without full scripts/transcripts')
    options = parser.parse_args()
    result = report()
    if options.metadata:
        emitted = {'summary': result['summary'], 'clips': result['metadata']}
    else:
        emitted = result if options.manifest else result['summary']
    print(json.dumps(emitted, ensure_ascii=False, indent=2))
