"""Verify bundled lesson content and all catalogued audio in the Android APK."""
import hashlib
import json
from pathlib import Path
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
apk = Path(sys.argv[1])
prefix = 'assets/flutter_assets/'
audio_count = 0
with zipfile.ZipFile(apk) as package:
    assert package.testzip() is None, 'CRC failure'
    for abi in ['armeabi-v7a', 'arm64-v8a', 'x86_64']:
        assert f'lib/{abi}/libapp.so' in package.namelist(), abi
        assert f'lib/{abi}/libflutter.so' in package.namelist(), abi
    for filename, extra, count in [
        ('AUDIO_V48_MANIFEST.json', '', 18),
        ('AUDIO_V46_MANIFEST.json', '', 9),
        ('AUDIO_V45_MANIFEST.json', '', 13), ('AUDIO_V45_DERIVED.json', '', 4),
        ('AUDIO_V44_MANIFEST.json', '', 12), ('AUDIO_V43_MANIFEST.json', '', 42),
        ('AUDIO_V41_MANIFEST.json', 'assets/audio/', 52),
    ]:
        entries = json.loads((root / filename).read_text(encoding='utf-8'))
        assert len(entries) == count
        for path, entry in entries.items():
            assert hashlib.sha256(package.read(prefix + extra + path)).hexdigest() == entry['sha256'], path
            audio_count += 1
    for slug in ['alif', 'baa', 'taa', 'thaa', 'jeem', 'haa', 'khaa']:
        path = f'assets/content/lesson_{slug}.json'
        assert json.loads(package.read(prefix + path)) == json.loads((root / path).read_text(encoding='utf-8'))
    checkpoint = 'assets/content/lesson_checkpoint_group_1.json'
    assert json.loads(package.read(prefix + checkpoint)) == json.loads(
        (root / checkpoint).read_text(encoding='utf-8'))
print(json.dumps({'status': 'PASS', 'bytes': apk.stat().st_size,
                  'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
                  'verifiedAudioFiles': audio_count, 'lessons': 8,
                  'abis': ['armeabi-v7a', 'arm64-v8a', 'x86_64'], 'CRC': 'PASS'}, indent=2))
