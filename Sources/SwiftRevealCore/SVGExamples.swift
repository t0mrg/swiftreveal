import Foundation

/// Small original fixtures double as editable import examples and export checks.
public enum SVGExamples {
    public static let figure = Data("""
    <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="600" viewBox="0 0 1200 600">
      <defs>
        <linearGradient id="panel" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#e7effa"/><stop offset="1" stop-color="#d6f1ec"/>
        </linearGradient>
        <marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#174d8f"/></marker>
        <clipPath id="chart-clip"><rect x="90" y="300" width="1020" height="200" rx="16"/></clipPath>
        <style>.heading{font-family:Arial,sans-serif;font-size:34px;font-weight:700;fill:#174d8f}.label{font-family:Arial,sans-serif;font-size:28px;text-anchor:middle;fill:#174d8f}.caption{font-family:Arial,sans-serif;font-size:22px;fill:#555e6a}</style>
      </defs>
      <rect x="4" y="4" width="1192" height="592" rx="28" fill="#ffffff" stroke="#dfe3e9" stroke-width="3"/>
      <text class="heading" x="60" y="70">A self-contained SVG figure</text>
      <g fill="url(#panel)" stroke="#2a78d6" stroke-width="3">
        <rect x="70" y="125" width="280" height="120" rx="18"/>
        <rect x="460" y="125" width="280" height="120" rx="18"/>
        <rect x="850" y="125" width="280" height="120" rx="18"/>
      </g>
      <g class="label"><text x="210" y="195">Input</text><text x="600" y="195">Process</text><text x="990" y="195">Output</text></g>
      <g stroke="#174d8f" stroke-width="4" marker-end="url(#arrow)"><path d="M 360 185 H 440"/><path d="M 750 185 H 830"/></g>
      <g clip-path="url(#chart-clip)">
        <rect x="90" y="300" width="1020" height="200" fill="url(#panel)"/>
        <path d="M 70 480 C 270 470 300 320 500 360 S 820 520 1130 310" fill="none" stroke="#087f8c" stroke-width="8"/>
      </g>
      <text class="caption" x="90" y="550">Vector text, paths, gradients, clipping and arrowheads — illustrative artwork.</text>
    </svg>
    """.utf8)

    public static let background = Data("""
    <svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">
      <defs>
        <linearGradient id="base" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#123d73"/><stop offset="1" stop-color="#087f8c"/></linearGradient>
        <radialGradient id="glow"><stop offset="0" stop-color="#73b6fa" stop-opacity="0.6"/><stop offset="1" stop-color="#73b6fa" stop-opacity="0"/></radialGradient>
      </defs>
      <rect width="1600" height="900" fill="url(#base)"/>
      <circle cx="1300" cy="200" r="650" fill="url(#glow)"/>
      <g fill="none" stroke="#ffffff" stroke-opacity="0.14" stroke-width="3">
        <path d="M -100 750 C 350 200 900 1100 1700 300"/>
        <path d="M -100 800 C 350 250 900 1150 1700 350"/>
        <path d="M -100 850 C 350 300 900 1200 1700 400"/>
      </g>
    </svg>
    """.utf8)

    public static func deck() throws -> Deck {
        let vectorFigure = try SVGImage.sanitize(figure)
        let vectorBackground = try SVGImage.sanitize(background)
        return Deck(title: "SVG images", footer: "SwiftReveal", slides: [
            Slide(layout: .title, title: "Vector backgrounds", subtitle: "A scalable SVG background with the usual overlay controls",
                  background: SlideBackground(imageData: vectorBackground, imageMIME: "image/svg+xml", overlayColor: "#102036", overlayOpacity: 0.2),
                  centerTitleHorizontally: true, centerTitleVertically: true),
            Slide(layout: .figure, title: "SVG figure", blocks: [ContentBlock(kind: .figure, caption: "Original illustrative vector artwork · fit/crop, save and copy like other figures", imageData: vectorFigure, imageMIME: "image/svg+xml")])
        ])
    }
}
