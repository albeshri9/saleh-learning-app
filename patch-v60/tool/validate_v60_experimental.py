"""Validate the user's explicit experimental IPA exception, not production QA."""
import hashlib
import json
from pathlib import Path

from validate_v60_readiness import ROOT, PENDING, validate
from validate_content import validate as validate_content
from validate_voice_bindings import validate as validate_voice_bindings


def validate_experimental(root=ROOT):
    root = Path(root)
    approval = json.loads((root / 'EXPERIMENTAL_V60_AUTHORIZATION.json').read_text(encoding='utf-8'))
    errors = []
    if (approval.get('version') != 60 or approval.get('releaseChannel') != 'experimental'
            or approval.get('allowUnreviewedAudioInExperimentalIpa') is not True
            or approval.get('auditoryApprovalGranted') is not False
            or approval.get('productionReleaseAllowed') is not False):
        errors.append('Missing or invalid experimental-only authorization')
    pending = root / 'pending_content/v60'
    report = validate(pending=pending, project_root=root)
    for blocker in report['blockers']:
        if blocker['category'] != 'audio-manual-qa-pending':
            errors.append(str(blocker))
    manifest = json.loads((pending / 'NARRATION_V60_PENDING.json').read_text(encoding='utf-8'))
    reading = json.loads((pending / 'READING_AUDIO_QA.json').read_text(encoding='utf-8'))
    rows = reading if isinstance(reading, list) else next(reading[k] for k in ('clips', 'assets', 'audio') if k in reading)
    for clip in manifest['clips'] + rows:
        asset = clip.get('asset') or clip.get('path')
        target = root / asset
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest().lower() != clip['sha256'].lower():
            errors.append('Integrated audio differs from reviewed candidate: ' + asset)
    errors.extend(validate_content(root))
    errors.extend(validate_voice_bindings())
    return errors, report


if __name__ == '__main__':
    errors, report = validate_experimental()
    if errors:
        raise SystemExit('\n'.join(errors))
    print('Experimental v60 checks passed. User permitted pending auditory review in this IPA only.')
    print(json.dumps(report['counts']))
    print('Not production approval; no auditory QA flag was modified.')
