#!/usr/bin/env python3
"""Generate checksums and a Homebrew cask from the exact release archives."""
import hashlib
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def generate(root: Path) -> None:
    metadata = plistlib.loads((root / 'packaging/Info.plist').read_bytes())
    version = metadata['CFBundleShortVersionString']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Release version must use major.minor.patch')
    checksums = {}
    for arch in ('arm64', 'x86_64'):
        archive = root / 'dist' / f'SwiftReveal-macOS-{arch}.zip'
        checksums[arch] = hashlib.sha256(archive.read_bytes()).hexdigest()
    (root / 'dist/SHA256SUMS').write_text(''.join(
        f'{checksum}  SwiftReveal-macOS-{arch}.zip\n'
        for arch, checksum in checksums.items()))
    cask = f'''cask "swiftreveal" do
  arch arm: "arm64", intel: "x86_64"

  version "{version}"
  on_arm do
    sha256 "{checksums['arm64']}"
  end
  on_intel do
    sha256 "{checksums['x86_64']}"
  end

  url "https://github.com/t0mrg/swiftreveal/releases/download/v#{{version}}/SwiftReveal-macOS-#{{arch}}.zip"
  name "SwiftReveal"
  desc "Native editor for structured slide presentations"
  homepage "https://github.com/t0mrg/swiftreveal"

  depends_on macos: :sonoma

  app "SwiftReveal.app"

  caveats <<~EOS
    SwiftReveal is ad-hoc signed and is not yet notarized by Apple.
    macOS may block the first launch. Follow the first-launch instructions at:
      https://github.com/t0mrg/swiftreveal#install
  EOS
end
'''
    (root / 'dist/swiftreveal.rb').write_text(cask)
    print(f'Prepared SwiftReveal {version}: SHA256SUMS and swiftreveal.rb')


if __name__ == '__main__':
    generate(ROOT)
