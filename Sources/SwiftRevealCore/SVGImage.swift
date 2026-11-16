import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Imports static, self-contained SVG artwork. This is deliberately separate from
/// Mermaid: plotting-tool SVG may use text, gradients, masks and complex defs.
/// Unsupported active content and resource-loading CSS fail visibly rather than
/// changing the artwork silently. The result belongs in an isolated <img> data URI.
public enum SVGImage {
    public static let maximumBytes = 20 * 1_024 * 1_024

    public static func sanitize(_ data: Data) throws -> Data {
        guard data.count <= maximumBytes else { throw SVGImageError.tooLarge }
        var source: String
        if let string = String(data: data, encoding: .utf8) { source = string }
        else if data.starts(with: [0xFF, 0xFE]), let string = String(data: data, encoding: .utf16LittleEndian) { source = string }
        else if data.starts(with: [0xFE, 0xFF]), let string = String(data: data, encoding: .utf16BigEndian) { source = string }
        else { throw SVGImageError.malformedXML }
        if source.first == "\u{FEFF}" { source.removeFirst() }
        source = try removingExternalSVGDoctype(source)
        // Normalize a UTF-16 declaration after converting the input to UTF-8.
        if let declaration = source.range(of: #"^<\?xml\s[^?]*\?>"#, options: .regularExpression) {
            let header = String(source[declaration])
            let expression = try NSRegularExpression(pattern: #"encoding\s*=\s*(['"])([^'"]+)\1"#)
            if let match = expression.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)),
               let encodingRange = Range(match.range(at: 2), in: header) {
                let encoding = header[encodingRange].lowercased()
                guard ["utf-8", "utf8", "utf-16", "utf-16le", "utf-16be"].contains(encoding) else { throw SVGImageError.unsupported("XML encoding") }
                let normalized = expression.stringByReplacingMatches(in: header, range: NSRange(header.startIndex..., in: header), withTemplate: "encoding=\"UTF-8\"")
                source.replaceSubrange(declaration, with: normalized)
            }
        }
        let delegate = StaticSVGParser()
        let parser = XMLParser(data: Data(source.utf8))
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = delegate
        let parsed = parser.parse()
        if let error = delegate.failure { throw error }
        guard parsed, delegate.hasRoot, delegate.stack.isEmpty else { throw SVGImageError.malformedXML }
        let result = Data(("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + delegate.output).utf8)
        guard result.count <= maximumBytes else { throw SVGImageError.tooLarge }
        return result
    }

    private static func doctypeRange(in source: String) throws -> Range<String.Index>? {
        var cursor = source.startIndex
        while let opening = source.range(of: "<", range: cursor..<source.endIndex) {
            cursor = opening.lowerBound
            let tail = source[cursor...]
            let ending: String?
            if tail.hasPrefix("<!--") { ending = "-->" }
            else if tail.hasPrefix("<![CDATA[") { ending = "]]>" }
            else if tail.hasPrefix("<?") { ending = "?>" }
            else { ending = nil }
            if let ending {
                guard let end = source.range(of: ending, range: cursor..<source.endIndex) else { throw SVGImageError.malformedXML }
                cursor = end.upperBound
            } else if let end = source.index(cursor, offsetBy: 9, limitedBy: source.endIndex), source[cursor..<end].uppercased() == "<!DOCTYPE" {
                return cursor..<end
            } else { cursor = source.index(after: cursor) }
        }
        return nil
    }

    /// Matplotlib's conventional, external-only W3C SVG declaration is harmless
    /// once removed. Never ask XMLParser to fetch any DTD, and reject subsets.
    private static func removingExternalSVGDoctype(_ source: String) throws -> String {
        guard let start = try doctypeRange(in: source) else { return source }
        var cursor = start.upperBound, quote: Character?
        while cursor < source.endIndex {
            let char = source[cursor]
            if char == "[" { throw SVGImageError.unsafeContent("DTD internal subsets") }
            if let current = quote { if char == current { quote = nil } }
            else if char == "\"" || char == "'" { quote = char }
            else if char == ">" { break }
            cursor = source.index(after: cursor)
        }
        guard cursor < source.endIndex, quote == nil else { throw SVGImageError.malformedXML }
        let declaration = String(source[start.upperBound..<cursor])
        var tokens: [(String, Bool)] = [], index = declaration.startIndex
        while index < declaration.endIndex {
            while index < declaration.endIndex && declaration[index].isWhitespace { index = declaration.index(after: index) }
            guard index < declaration.endIndex else { break }
            let char = declaration[index]
            if char == "\"" || char == "'" {
                index = declaration.index(after: index); let begin = index
                while index < declaration.endIndex && declaration[index] != char { index = declaration.index(after: index) }
                guard index < declaration.endIndex else { throw SVGImageError.malformedXML }
                tokens.append((String(declaration[begin..<index]), true)); index = declaration.index(after: index)
            } else {
                let begin = index
                while index < declaration.endIndex && !declaration[index].isWhitespace { index = declaration.index(after: index) }
                tokens.append((String(declaration[begin..<index]), false))
            }
        }
        let known: [String: Set<String>] = [
            "-//W3C//DTD SVG 1.1//EN": ["http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd", "https://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"],
            "-//W3C//DTD SVG 1.0//EN": ["http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd", "http://www.w3.org/Graphics/SVG/1.0/DTD/svg10.dtd"]
        ]
        let validPublic = tokens.count == 4 && tokens[0].0 == "svg" && !tokens[0].1 && tokens[1].0 == "PUBLIC" && !tokens[1].1 && tokens[2].1 && tokens[3].1 && known[tokens[2].0]?.contains(tokens[3].0) == true
        let validSystem = tokens.count == 3 && tokens[0].0 == "svg" && !tokens[0].1 && tokens[1].0 == "SYSTEM" && !tokens[1].1 && tokens[2].1 && known.values.contains(where: { $0.contains(tokens[2].0) })
        guard source[start] == "<!DOCTYPE", validPublic || validSystem else { throw SVGImageError.unsafeContent("unrecognized DTD") }
        var result = source
        result.removeSubrange(start.lowerBound...cursor)
        guard try doctypeRange(in: result) == nil else { throw SVGImageError.malformedXML }
        return result
    }
}

public enum SVGImageError: LocalizedError, Equatable {
    case tooLarge, malformedXML, invalidDimensions, tooComplex, unsafeContent(String), unsupported(String)
    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "The SVG exceeds the 20 MB image limit."
        case .malformedXML: return "The SVG is not a well-formed UTF-8 or UTF-16 XML document."
        case .invalidDimensions: return "The SVG needs a valid viewBox or positive intrinsic width and height."
        case .tooComplex: return "The SVG contains too many elements or too much nesting. Simplify it before importing."
        case .unsafeContent(let kind): return "The SVG contains unsafe content (\(kind)). Export a static, self-contained SVG instead."
        case .unsupported(let kind): return "The SVG uses an unsupported feature (\(kind)). Export plain static SVG, or convert text to paths."
        }
    }
}

private final class StaticSVGParser: NSObject, XMLParserDelegate {
    struct Frame {
        let name: String
        let namespaces: [String: String]
        let skipped: Bool
        var style = ""
    }
    private static let svgNamespace = "http://www.w3.org/2000/svg"
    private static let xlinkNamespace = "http://www.w3.org/1999/xlink"
    private static let xmlNamespace = "http://www.w3.org/XML/1998/namespace"
    private static let editorNamespaces: Set<String> = ["http://www.inkscape.org/namespaces/inkscape", "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"]
    private static let elements: Set<String> = ["svg", "g", "defs", "symbol", "use", "view", "switch", "title", "desc", "style", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "text", "tspan", "textPath", "linearGradient", "radialGradient", "stop", "clipPath", "mask", "pattern", "marker", "image", "filter", "feBlend", "feColorMatrix", "feComponentTransfer", "feComposite", "feConvolveMatrix", "feDiffuseLighting", "feDisplacementMap", "feDistantLight", "feDropShadow", "feFlood", "feFuncA", "feFuncB", "feFuncG", "feFuncR", "feGaussianBlur", "feImage", "feMerge", "feMergeNode", "feMorphology", "feOffset", "fePointLight", "feSpecularLighting", "feSpotLight", "feTile", "feTurbulence"]
    private static let activeElements: Set<String> = ["script", "foreignobject", "animate", "animatetransform", "animatemotion", "set", "discard", "mpath", "handler", "listener"]
    private static let attributes: Set<String> = Set("id class version baseProfile x y x1 y1 x2 y2 cx cy r rx ry width height viewBox preserveAspectRatio d points pathLength transform gradientUnits gradientTransform spreadMethod fx fy fr patternUnits patternContentUnits patternTransform maskUnits maskContentUnits clipPathUnits markerUnits markerWidth markerHeight orient refX refY filterUnits primitiveUnits filterRes result in in2 mode type values tableValues slope intercept amplitude exponent offset operator k1 k2 k3 k4 order kernelMatrix divisor bias targetX targetY edgeMode kernelUnitLength preserveAlpha surfaceScale diffuseConstant specularConstant specularExponent limitingConeAngle pointsAtX pointsAtY pointsAtZ azimuth elevation scale xChannelSelector yChannelSelector stdDeviation baseFrequency numOctaves seed stitchTiles radius textLength lengthAdjust dx dy rotate startOffset method spacing side requiredFeatures systemLanguage enable-background role aria-label aria-labelledby aria-describedby".split(separator: " ").map(String.init))
    static let presentation: Set<String> = Set("fill fill-opacity fill-rule stroke stroke-opacity stroke-width stroke-dasharray stroke-dashoffset stroke-linecap stroke-linejoin stroke-miterlimit paint-order vector-effect opacity color color-interpolation color-interpolation-filters color-rendering image-rendering shape-rendering text-rendering clip-rule clip-path mask filter marker-start marker-mid marker-end display visibility overflow isolation mix-blend-mode font font-family font-size font-size-adjust font-stretch font-style font-variant font-weight font-feature-settings font-kerning font-variant-ligatures font-variant-caps font-variant-numeric font-variant-east-asian font-variation-settings letter-spacing word-spacing text-anchor text-decoration dominant-baseline alignment-baseline baseline-shift writing-mode direction unicode-bidi glyph-orientation-horizontal glyph-orientation-vertical lighting-color flood-color flood-opacity stop-color stop-opacity solid-color solid-opacity stroke-alignment text-align text-indent white-space line-height text-orientation text-transform text-decoration-color text-decoration-style text-decoration-line text-decoration-thickness shape-inside shape-padding shape-margin -inkscape-font-specification".split(separator: " ").map(String.init))

    var failure: SVGImageError?
    var output = ""
    var stack: [Frame] = []
    var hasRoot = false
    private var elementCount = 0

    private func fail(_ error: SVGImageError, parser: XMLParser) { if failure == nil { failure = error }; parser.abortParsing() }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes values: [String: String]) {
        do {
            elementCount += 1
            guard elementCount <= 200_000, stack.count < 128, values.count <= 256 else { throw SVGImageError.tooComplex }
            var namespaces = stack.last?.namespaces ?? ["": Self.svgNamespace, "xml": Self.xmlNamespace]
            for (name, value) in values {
                if name == "xmlns" { namespaces[""] = value }
                else if name.hasPrefix("xmlns:") { namespaces[String(name.dropFirst(6))] = value }
            }
            let parts = elementName.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count <= 2 else { throw SVGImageError.malformedXML }
            let name = String(parts.last!), prefix = parts.count == 2 ? String(parts[0]) : ""
            let namespace = namespaces[prefix]
            let skipped = stack.last?.skipped == true || (namespace == Self.svgNamespace && name == "metadata") || Self.editorNamespaces.contains(namespace ?? "")
            if skipped { stack.append(Frame(name: name, namespaces: namespaces, skipped: true)); return }
            guard stack.last?.name != "style" else { throw SVGImageError.malformedXML }
            guard namespace == Self.svgNamespace else { throw SVGImageError.unsupported("foreign XML namespace") }
            guard !Self.activeElements.contains(name.lowercased()) else { throw SVGImageError.unsafeContent(name) }
            guard Self.elements.contains(name) else { throw SVGImageError.unsupported("element \(name)") }
            if stack.isEmpty {
                guard !hasRoot, name == "svg" else { throw SVGImageError.malformedXML }
                try validateDimensions(values)
                hasRoot = true
            }
            var attributes: [String: String] = [:]
            for (attribute, value) in values {
                if attribute == "xmlns" || attribute.hasPrefix("xmlns:") { continue }
                let components = attribute.split(separator: ":", omittingEmptySubsequences: false)
                guard components.count <= 2 else { throw SVGImageError.malformedXML }
                let local = String(components.last!)
                guard !local.lowercased().hasPrefix("on") else { throw SVGImageError.unsafeContent("event handlers") }
                if components.count == 2 {
                    let uri = namespaces[String(components[0])]
                    if Self.editorNamespaces.contains(uri ?? "") { continue }
                    if uri == Self.xlinkNamespace && local == "href" {
                        attributes["xlink:href"] = try safeReference(value, element: name); continue
                    }
                    if uri == Self.xmlNamespace && ["space", "lang"].contains(local) { attributes["xml:" + local] = value; continue }
                    throw SVGImageError.unsupported("namespaced attribute")
                }
                if local == "href" { attributes[local] = try safeReference(value, element: name) }
                else if local == "style" { attributes[local] = try StaticSVGCSS.declarations(value) }
                else if Self.presentation.contains(local) { try StaticSVGCSS.validateValue(value); attributes[local] = value }
                else if Self.attributes.contains(local) {
                    if local == "type", name == "style", !value.isEmpty, value.lowercased() != "text/css" { throw SVGImageError.unsupported("style language") }
                    attributes[local] = value
                } else if local.hasPrefix("aria-") || local.hasPrefix("data-") || local == "lang" { attributes[local] = value }
                else { throw SVGImageError.unsupported("attribute \(local)") }
            }
            if stack.isEmpty {
                attributes["xmlns"] = Self.svgNamespace
                attributes["xmlns:xlink"] = Self.xlinkNamespace
            }
            output += "<" + name
            for key in attributes.keys.sorted() { output += " \(key)=\"\(xmlEscape(attributes[key]!))\"" }
            output += ">"
            stack.append(Frame(name: name, namespaces: namespaces, skipped: false))
        } catch let error as SVGImageError { fail(error, parser: parser) }
        catch { fail(.malformedXML, parser: parser) }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let frame = stack.popLast(), !frame.skipped else { return }
        do {
            if frame.name == "style" { output += xmlEscape(try StaticSVGCSS.stylesheet(frame.style)) }
            output += "</" + frame.name + ">"
        } catch let error as SVGImageError { fail(error, parser: parser) }
        catch { fail(.malformedXML, parser: parser) }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let frame = stack.last, !frame.skipped else { return }
        if frame.name == "style" { stack[stack.count - 1].style += string }
        else { output += xmlEscape(string) }
    }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let value = String(data: CDATABlock, encoding: .utf8) else { fail(.malformedXML, parser: parser); return }
        self.parser(parser, foundCharacters: value)
    }
    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) { fail(.unsafeContent("processing instructions"), parser: parser) }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { fail(.unsafeContent("entity declarations"), parser: parser) }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { fail(.unsafeContent("entity declarations"), parser: parser) }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? { fail(.unsafeContent("external entities"), parser: parser); return nil }
    func parser(_ parser: XMLParser, foundSkippedEntityName name: String) { fail(.unsafeContent("unresolved entities"), parser: parser) }

    private func safeReference(_ raw: String, element: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if StaticSVGCSS.isLocalReference(value) { return value }
        if ["image", "feImage"].contains(element) {
            for (mime, signature) in [("image/png", [UInt8](arrayLiteral: 137, 80, 78, 71, 13, 10, 26, 10)), ("image/jpeg", [UInt8](arrayLiteral: 255, 216, 255))] {
                let prefix = "data:\(mime);base64,"
                if value.hasPrefix(prefix) {
                    let encoded = value.dropFirst(prefix.count)
                    guard encoded.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "+/=".contains($0) || $0.isWhitespace) }),
                          let bytes = Data(base64Encoded: String(encoded.filter { !$0.isWhitespace })), bytes.starts(with: signature) else { throw SVGImageError.unsafeContent("invalid embedded image") }
                    return prefix + bytes.base64EncodedString()
                }
            }
        }
        throw SVGImageError.unsafeContent("external or unsupported image references")
    }

    private func validateDimensions(_ attributes: [String: String]) throws {
        let hasViewBox: Bool
        if let value = attributes["viewBox"] {
            let parts = value.split(whereSeparator: { $0.isWhitespace || $0 == "," })
            let values = parts.compactMap { Double($0) }
            guard parts.count == 4, values.count == 4, values.allSatisfy(\.isFinite), values[2] > 0, values[3] > 0 else { throw SVGImageError.invalidDimensions }
            hasViewBox = true
        } else { hasViewBox = false }
        func validLength(_ value: String, percentages: Bool) -> Bool {
            let pattern = percentages ? #"^\+?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?(?:px|pt|pc|cm|mm|in|em|ex|q|%)?$"# : #"^\+?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?(?:px|pt|pc|cm|mm|in|em|ex|q)?$"#
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.range(of: pattern, options: .regularExpression) != nil,
                  let number = clean.range(of: #"^\+?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"#, options: .regularExpression).flatMap({ Double(clean[$0]) }) else { return false }
            return number.isFinite && number > 0
        }
        for key in ["width", "height"] {
            if let value = attributes[key], !validLength(value, percentages: hasViewBox) { throw SVGImageError.invalidDimensions }
        }
        guard hasViewBox || (attributes["width"].map { validLength($0, percentages: false) } == true && attributes["height"].map { validLength($0, percentages: false) } == true) else { throw SVGImageError.invalidDimensions }
    }
}

private enum StaticSVGCSS {
    private static let functions: Set<String> = ["rgb", "rgba", "hsl", "hsla", "hwb", "lab", "lch", "oklab", "oklch", "color", "color-mix", "calc", "min", "max", "clamp", "translate", "translatex", "translatey", "translate3d", "scale", "scalex", "scaley", "scale3d", "rotate", "rotatex", "rotatey", "rotatez", "rotate3d", "skew", "skewx", "skewy", "matrix", "matrix3d", "perspective", "blur", "brightness", "contrast", "drop-shadow", "grayscale", "hue-rotate", "invert", "opacity", "saturate", "sepia"]

    static func isLocalReference(_ value: String) -> Bool {
        value.first == "#" && value.count > 1 && value.dropFirst().allSatisfy { $0.isLetter || $0.isNumber || "_.:-".contains($0) }
    }

    /// Reject escapes rather than attempting partial CSS unescaping. Reject all
    /// @rules, custom properties and unrecognized functions, including web fonts.
    private static func clean(_ source: String) throws -> String {
        guard !source.contains("\\"), !source.contains("@"), !source.contains("\u{0000}") else { throw SVGImageError.unsafeContent("CSS escapes or at-rules") }
        let chars = Array(source)
        var output = "", cursor = 0, quote: Character?
        while cursor < chars.count {
            let char = chars[cursor]
            if let current = quote { output.append(char); if char == current { quote = nil }; cursor += 1 }
            else if char == "\"" || char == "'" { quote = char; output.append(char); cursor += 1 }
            else if cursor + 1 < chars.count && char == "/" && chars[cursor + 1] == "*" {
                cursor += 2
                while cursor + 1 < chars.count && !(chars[cursor] == "*" && chars[cursor + 1] == "/") { cursor += 1 }
                guard cursor + 1 < chars.count else { throw SVGImageError.unsafeContent("malformed CSS comment") }
                cursor += 2
            } else { output.append(char); cursor += 1 }
        }
        guard quote == nil else { throw SVGImageError.unsafeContent("malformed CSS string") }
        return output
    }

    static func validateValue(_ source: String) throws {
        let chars = Array(try clean(source))
        var cursor = 0, quote: Character?, depth = 0
        while cursor < chars.count {
            let char = chars[cursor]
            if let current = quote { if char == current { quote = nil }; cursor += 1; continue }
            if char == "\"" || char == "'" { quote = char; cursor += 1; continue }
            if char.isLetter || char == "_" || char == "-" {
                let start = cursor
                while cursor < chars.count && (chars[cursor].isLetter || chars[cursor].isNumber || chars[cursor] == "_" || chars[cursor] == "-") { cursor += 1 }
                let token = String(chars[start..<cursor]).lowercased()
                var next = cursor
                while next < chars.count && chars[next].isWhitespace { next += 1 }
                if next < chars.count && chars[next] == "(" {
                    if token == "url" {
                        let begin = next + 1
                        var end = begin
                        while end < chars.count && chars[end] != ")" { end += 1 }
                        guard end < chars.count else { throw SVGImageError.unsafeContent("malformed CSS URL") }
                        var target = String(chars[begin..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if let first = target.first, first == "\"" || first == "'" {
                            guard target.last == first, target.count >= 2 else { throw SVGImageError.unsafeContent("malformed CSS URL") }
                            target.removeFirst(); target.removeLast()
                        }
                        guard isLocalReference(target) else { throw SVGImageError.unsafeContent("external CSS URL") }
                        cursor = end + 1
                    } else {
                        guard functions.contains(token) else { throw SVGImageError.unsupported("CSS function \(token)") }
                    }
                }
            } else if char == "(" { depth += 1; guard depth <= 64 else { throw SVGImageError.tooComplex }; cursor += 1 }
            else if char == ")" { depth -= 1; guard depth >= 0 else { throw SVGImageError.unsafeContent("malformed CSS") }; cursor += 1 }
            else if "{};".contains(char) { throw SVGImageError.unsafeContent("malformed CSS value") }
            else { cursor += 1 }
        }
        guard quote == nil, depth == 0 else { throw SVGImageError.unsafeContent("malformed CSS") }
    }

    static func declarations(_ source: String) throws -> String {
        let clean = try clean(source)
        var declarations: [String] = [], current = "", quote: Character?, depth = 0
        func consume() throws {
            let declaration = current.trimmingCharacters(in: .whitespacesAndNewlines)
            current = ""
            guard !declaration.isEmpty else { return }
            guard let colon = declaration.firstIndex(of: ":") else { throw SVGImageError.unsafeContent("malformed CSS declaration") }
            let property = declaration[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard StaticSVGParser.presentation.contains(property) else { throw SVGImageError.unsupported("CSS property \(property)") }
            let value = declaration[declaration.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { throw SVGImageError.unsafeContent("empty CSS value") }
            try validateValue(value)
            declarations.append(property + ":" + value)
        }
        for char in clean {
            if let currentQuote = quote { current.append(char); if char == currentQuote { quote = nil } }
            else if char == "\"" || char == "'" { quote = char; current.append(char) }
            else if char == "(" { depth += 1; guard depth <= 64 else { throw SVGImageError.tooComplex }; current.append(char) }
            else if char == ")" { depth -= 1; guard depth >= 0 else { throw SVGImageError.unsafeContent("malformed CSS") }; current.append(char) }
            else if char == ";" && depth == 0 { try consume() }
            else { current.append(char) }
        }
        guard depth == 0, quote == nil else { throw SVGImageError.unsafeContent("malformed CSS") }
        try consume()
        return declarations.joined(separator: ";")
    }

    static func stylesheet(_ source: String) throws -> String {
        let chars = Array(try clean(source))
        var cursor = 0, output = ""
        while cursor < chars.count {
            while cursor < chars.count && chars[cursor].isWhitespace { cursor += 1 }
            guard cursor < chars.count else { break }
            let selectorStart = cursor
            var quote: Character?
            while cursor < chars.count {
                let char = chars[cursor]
                if let current = quote { if char == current { quote = nil } }
                else if char == "\"" || char == "'" { quote = char }
                else if char == "{" { break }
                else if char == "}" || char == ";" { throw SVGImageError.unsafeContent("malformed CSS selector") }
                cursor += 1
            }
            guard cursor < chars.count, quote == nil else { throw SVGImageError.unsafeContent("malformed CSS rule") }
            let selector = String(chars[selectorStart..<cursor]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selector.isEmpty, !selector.contains("<"), !selector.contains(">>") else { throw SVGImageError.unsafeContent("malformed CSS selector") }
            cursor += 1; let bodyStart = cursor
            while cursor < chars.count {
                let char = chars[cursor]
                if let current = quote { if char == current { quote = nil } }
                else if char == "\"" || char == "'" { quote = char }
                else if char == "}" { break }
                else if char == "{" { throw SVGImageError.unsupported("nested CSS rules") }
                cursor += 1
            }
            guard cursor < chars.count, quote == nil else { throw SVGImageError.unsafeContent("malformed CSS rule") }
            output += selector + "{" + (try declarations(String(chars[bodyStart..<cursor]))) + "}"
            cursor += 1
        }
        return output
    }
}

private func xmlEscape(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
}
