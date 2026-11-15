SwiftReveal 0.6.0

- Open presentations in separate windows using New window/Open controls or standard document commands.
- Select multiple navigator slides and copy/paste across presentations in source order, above the selected destination slide. Copied slides inherit the receiving deck theme/CSS while retaining custom slide/block settings and embedded assets.
- Slide-specific copy/paste buttons and commands supplement standard navigator ⌘C/⌘V without taking over text editing shortcuts.
- Repair Mermaid node-label centring and overflow by preserving SVG centre anchors and matching measurement/output typography.

Automated transfer tests cover destination-theme isolation, custom colours, images/backgrounds, ordering, position and new identities. The in-app integration checks include Mermaid label geometry. The user has accepted the testing build, including the requested slide-transfer feature and Mermaid label fix. Requires macOS 14 or newer; Apple silicon and Intel ZIPs, SHA-256 checksums and a matching Homebrew cask are included. The app is ad-hoc signed and not Apple-notarized; see README.md for first-launch instructions.
