import hashlib
import importlib.util
import plistlib
import struct
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('manifest', ROOT / 'scripts/release-manifest.py')
manifest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manifest)


class ReleaseTests(unittest.TestCase):
    def test_cask_and_checksums_match_both_archives(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'dist').mkdir()
            (root / 'packaging').mkdir()
            (root / 'packaging/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '1.2.3'}))
            for arch in ('arm64', 'x86_64'):
                (root / f'dist/SwiftReveal-macOS-{arch}.zip').write_bytes(arch.encode())
            manifest.generate(root)
            sums = (root / 'dist/SHA256SUMS').read_text()
            cask = (root / 'dist/swiftreveal.rb').read_text()
            for arch in ('arm64', 'x86_64'):
                digest = hashlib.sha256(arch.encode()).hexdigest()
                self.assertIn(f'{digest}  SwiftReveal-macOS-{arch}.zip', sums)
                self.assertIn(digest, cask)
            self.assertIn('version "1.2.3"', cask)
            self.assertIn('#{version}', cask)
            self.assertIn('#{arch}', cask)
            self.assertNotIn('postflight', cask)  # Do not silently disable quarantine.

    def test_icon_is_wired_into_bundle_and_has_small_and_retina_sizes(self):
        info = plistlib.loads((ROOT / 'packaging/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleIconFile'], 'AppIcon')
        data = (ROOT / 'packaging/AppIcon.icns').read_bytes()
        self.assertEqual(data[:4], b'icns')
        self.assertEqual(struct.unpack('>I', data[4:8])[0], len(data))
        tags = set()
        offset = 8
        while offset < len(data):
            tag, size = struct.unpack('>4sI', data[offset:offset+8])
            self.assertGreater(size, 8)
            self.assertEqual(data[offset+8:offset+16], b'\x89PNG\r\n\x1a\n')
            tags.add(tag)
            offset += size
        self.assertEqual(offset, len(data))
        self.assertTrue({b'icp4', b'ic07', b'ic09', b'ic10', b'ic11', b'ic14'} <= tags)

    def test_missing_architecture_fails_before_writing_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'dist').mkdir()
            (root / 'packaging').mkdir()
            (root / 'packaging/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '1.2.3'}))
            with self.assertRaises(FileNotFoundError):
                manifest.generate(root)
            self.assertFalse((root / 'dist/swiftreveal.rb').exists())
