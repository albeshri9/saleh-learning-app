"""Read-only verification of experimental v60-content IPAs and bundled assets."""
import hashlib
import json
from pathlib import Path
import plistlib
import sys
import zipfile


def verify(ipa, root, build_number='60'):
    ipa, root = Path(ipa), Path(root)
    checksum = Path(str(ipa) + '.sha256')
    with ipa.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    expected = checksum.read_text(encoding='utf-8-sig').split()[0].lower()
    if digest != expected:
        raise ValueError('Downloaded IPA checksum mismatch')
    pending = root / 'pending_content/v60'
    manifest = json.loads((pending / 'NARRATION_V60_PENDING.json').read_text(encoding='utf-8'))
    reading = json.loads((pending / 'READING_AUDIO_QA.json').read_text(encoding='utf-8'))
    reading_rows = reading if isinstance(reading, list) else next(
        reading[key] for key in ('clips', 'assets', 'audio') if key in reading)
    if len(manifest['clips']) + len(reading_rows) != 258:
        raise ValueError('Expected 258 audio records')
    prefix = 'Payload/Runner.app/Frameworks/App.framework/flutter_assets/'
    content_count, image_count = 0, 0
    with zipfile.ZipFile(ipa) as package:
        if package.testzip() is not None:
            raise ValueError('IPA CRC validation failed')
        info = plistlib.loads(package.read('Payload/Runner.app/Info.plist'))
        if str(info['CFBundleVersion']) != str(build_number):
            raise ValueError('Wrong iOS build number')
        if info.get('CFBundleDisplayName') != 'تعلم مع صالح':
            raise ValueError('Unexpected app display name')
        for binary in ('Runner', 'Frameworks/App.framework/App',
                       'Frameworks/Flutter.framework/Flutter'):
            if package.getinfo('Payload/Runner.app/' + binary).file_size == 0:
                raise ValueError('Missing iOS executable: ' + binary)
        for clip in manifest['clips'] + reading_rows:
            asset = clip.get('asset') or clip.get('path')
            if hashlib.sha256(package.read(prefix + asset)).hexdigest() != clip['sha256'].lower():
                raise ValueError('Bundled audio mismatch: ' + asset)
        for source in sorted((root / 'assets/content').glob('*.json')):
            asset = source.relative_to(root).as_posix()
            if json.loads(package.read(prefix + asset)) != json.loads(source.read_text(encoding='utf-8-sig')):
                raise ValueError('Bundled content mismatch: ' + asset)
            content_count += 1
        for source in sorted((pending / 'assets').rglob('*_v60.png')):
            asset = source.relative_to(pending).as_posix()
            if hashlib.sha256(package.read(prefix + asset)).digest() != hashlib.sha256(source.read_bytes()).digest():
                raise ValueError('Bundled image mismatch: ' + asset)
            image_count += 1
        packs = json.loads(package.read(prefix + 'assets/content/lesson_packs.json'))
        if len(packs['packs']) != 37:
            raise ValueError('Expected 37 lesson and assessment packs')
        if image_count != 16:
            raise ValueError('Expected 16 new word illustrations')
    return {
        'status': 'PASS', 'releaseChannel': 'experimental',
        'ipa': str(ipa.resolve()), 'bytes': ipa.stat().st_size,
        'sha256': digest, 'crc': 'PASS', 'buildNumber': info['CFBundleVersion'],
        'displayName': info['CFBundleDisplayName'], 'contentFiles': content_count,
        'audioFiles': len(manifest['clips']) + len(reading_rows), 'newImages': image_count,
        'packs': 37, 'auditoryApprovalGranted': False,
    }


if __name__ == '__main__':
    print(json.dumps(verify(sys.argv[1], Path(__file__).resolve().parents[1],
                            sys.argv[2] if len(sys.argv) > 2 else '60'),
                     ensure_ascii=False, indent=2))
