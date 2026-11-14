import Foundation

/// A conservative rich-text renderer. It reconstructs an explicit HTML allowlist,
/// never passes source tags through, and does not permit resource URLs or inline CSS.
public enum RichText {
    public static func inline(_ source: String) -> String { sanitize(source, allowBlocks: false) }

    public static func body(_ source: String) -> String {
        let safe = sanitize(source, allowBlocks: true)
        var output = "", list: String?, depth = 0
        for line in safe.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let tags = blockTags(in: line)
            let hasBlocks = !tags.isEmpty
            if depth == 0 && !hasBlocks && !trimmed.isEmpty {
                let bullet = trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ")
                let ordered = trimmed.range(of: #"^\d+[.)] "#, options: .regularExpression)
                let kind = bullet ? "ul" : ordered != nil ? "ol" : nil
                if kind != list { if let list { output += "</\(list)>" }; if let kind { output += "<\(kind)>" }; list = kind }
                if kind != nil {
                    let content = bullet ? String(trimmed.dropFirst(2)) : String(trimmed[(ordered?.upperBound ?? trimmed.startIndex)...])
                    output += "<li>\(content)</li>"
                } else { output += "<p>\(line)</p>" }
            } else {
                if let currentList = list { output += "</\(currentList)>"; list = nil }
                if !trimmed.isEmpty || depth > 0 { output += line + "\n" }
            }
            for (name, closing) in tags where !voidTags.contains(name) { depth = max(0, depth + (closing ? -1 : 1)) }
        }
        if let list { output += "</\(list)>" }
        return output.trimmingCharacters(in: .newlines)
    }

    private static let inlineTags: Set<String> = ["strong", "b", "em", "i", "u", "s", "del", "mark", "sub", "sup", "small", "code", "br", "span", "a", "kbd", "samp", "var"]
    private static let blocks: Set<String> = ["p", "div", "pre", "ul", "ol", "li", "blockquote", "h1", "h2", "h3", "h4", "h5", "h6", "table", "thead", "tbody", "tfoot", "tr", "td", "th", "hr"]
    private static let voidTags: Set<String> = ["br", "hr"]
    private static let forbiddenContainers: Set<String> = ["script", "style", "iframe", "object", "embed", "svg", "math", "form", "button", "select", "option", "textarea", "video", "audio", "picture", "canvas", "template", "noscript", "frameset", "frame", "applet", "xmp", "plaintext"]
    private static let forbiddenVoid: Set<String> = ["img", "input", "meta", "link", "base", "source", "track", "param", "area", "wbr"]

    private struct Tag {
        var name: String
        var closing: Bool
        var selfClosing: Bool
        var attributes: [(String, String)]
        var end: Int
    }

    private static func sanitize(_ source: String, allowBlocks: Bool) -> String {
        let chars = Array(source)
        var index = 0, output = "", buffer = "", stack: [String] = [], suppressed: [String] = []
        let allowed = allowBlocks ? inlineTags.union(blocks) : inlineTags
        func flush() {
            output += escaped(buffer)
            buffer = ""
        }
        while index < chars.count {
            if chars[index] == "<" {
                if starts(chars, at: index, with: "<!--") {
                    flush()
                    if let end = find(chars, from: index + 4, token: "-->") { index = end + 3 } else { index = chars.count }
                    continue
                }
                if index + 1 < chars.count && (chars[index + 1] == "!" || chars[index + 1] == "?") {
                    flush()
                    index = tagEnd(chars, from: index + 2).map { $0 + 1 } ?? chars.count
                    continue
                }
                if let tag = parseTag(chars, at: index) {
                    flush(); index = tag.end
                    if !suppressed.isEmpty {
                        if !tag.closing && forbiddenContainers.contains(tag.name) { suppressed.append(tag.name) }
                        else if tag.closing, let match = suppressed.lastIndex(of: tag.name) { suppressed.removeSubrange(match...) }
                        continue
                    }
                    if forbiddenVoid.contains(tag.name) { continue }
                    if forbiddenContainers.contains(tag.name) {
                        if !tag.closing { suppressed.append(tag.name) }
                        continue
                    }
                    guard allowed.contains(tag.name) else { continue }
                    if tag.closing {
                        if let match = stack.lastIndex(of: tag.name) {
                            for name in stack[match...].reversed() { output += "</\(name)>" }
                            stack.removeSubrange(match...)
                        }
                    } else {
                        // Close an existing paragraph before a new block container.
                        if blocks.contains(tag.name), let paragraph = stack.lastIndex(of: "p") {
                            for name in stack[paragraph...].reversed() { output += "</\(name)>" }
                            stack.removeSubrange(paragraph...)
                        }
                        output += "<\(tag.name)\(attributes(tag.attributes, for: tag.name))>"
                        if !voidTags.contains(tag.name) {
                            if tag.selfClosing { output += "</\(tag.name)>" }
                            else { stack.append(tag.name) }
                        }
                    }
                    continue
                }
            }
            if !suppressed.isEmpty { index += 1; continue }
            if chars[index] == "`", !stack.contains("pre"), !stack.contains("code"),
               let close = chars[(index + 1)...].firstIndex(of: "`") {
                flush()
                output += "<code>" + escaped(String(chars[(index + 1)..<close])) + "</code>"
                index = close + 1
                continue
            }
            buffer.append(chars[index]); index += 1
        }
        flush()
        for name in stack.reversed() { output += "</\(name)>" }
        return markdownAcrossMarkup(output)
    }

    private static func parseTag(_ chars: [Character], at start: Int) -> Tag? {
        var cursor = start + 1, closing = false
        if cursor < chars.count && chars[cursor] == "/" { closing = true; cursor += 1 }
        guard cursor < chars.count, asciiLetter(chars[cursor]) else { return nil }
        let nameStart = cursor
        while cursor < chars.count && (asciiLetter(chars[cursor]) || chars[cursor].isASCII && chars[cursor].isNumber || chars[cursor] == "-" || chars[cursor] == ":") { cursor += 1 }
        let name = String(chars[nameStart..<cursor]).lowercased()
        guard let end = tagEnd(chars, from: cursor) else { return nil }
        let selfClosing = String(chars[cursor..<end]).trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/")
        var attributes: [(String, String)] = []
        while cursor < end {
            while cursor < end && (chars[cursor].isWhitespace || chars[cursor] == "/") { cursor += 1 }
            let attributeStart = cursor
            while cursor < end && !chars[cursor].isWhitespace && !["=", "/", ">", "\"", "'", "<"].contains(chars[cursor]) { cursor += 1 }
            guard cursor > attributeStart else { cursor += 1; continue }
            let attribute = String(chars[attributeStart..<cursor]).lowercased()
            while cursor < end && chars[cursor].isWhitespace { cursor += 1 }
            var value = ""
            if cursor < end && chars[cursor] == "=" {
                cursor += 1
                while cursor < end && chars[cursor].isWhitespace { cursor += 1 }
                if cursor < end && (chars[cursor] == "\"" || chars[cursor] == "'") {
                    let quote = chars[cursor]; cursor += 1; let valueStart = cursor
                    while cursor < end && chars[cursor] != quote { cursor += 1 }
                    value = String(chars[valueStart..<cursor]); if cursor < end { cursor += 1 }
                } else {
                    let valueStart = cursor
                    while cursor < end && !chars[cursor].isWhitespace && chars[cursor] != ">" { cursor += 1 }
                    value = String(chars[valueStart..<cursor])
                }
            }
            attributes.append((attribute, value))
        }
        return Tag(name: name, closing: closing, selfClosing: selfClosing, attributes: attributes, end: end + 1)
    }

    private static func attributes(_ values: [(String, String)], for tag: String) -> String {
        var result = "", seen: Set<String> = []
        for (name, value) in values where !seen.contains(name) {
            seen.insert(name)
            if name == "class" {
                let tokens = value.split(whereSeparator: { $0.isWhitespace })
                let safe = tokens.filter { $0.count <= 80 && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") } }
                if !safe.isEmpty { result += " class=\"\(safe.prefix(12).joined(separator: " "))\"" }
            } else if name == "title" {
                result += " title=\"\(attributeEscape(String(value.prefix(500))))\""
            } else if ["td", "th"].contains(tag), ["colspan", "rowspan"].contains(name),
                      value.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(value), (1...100).contains(number) {
                result += " \(name)=\"\(number)\""
            }
        }
        return result
    }

    /// Protect reconstructed tags before Markdown parsing, so delimiters can span
    /// inline HTML without ever matching an attribute value. Code/pre content is
    /// protected as a whole and remains literal. The marker cannot occur in input.
    private static func markdownAcrossMarkup(_ html: String) -> String {
        let chars = Array(html)
        var prefix = "\u{E000}\u{E001}"
        while html.contains(prefix) { prefix += "\u{E001}" }
        let suffix = "\u{E002}"
        var tokens: [String] = [], protected = "", cursor = 0
        while cursor < chars.count {
            if chars[cursor] == "<", let tag = parseTag(chars, at: cursor) {
                var end = tag.end
                if !tag.closing && ["code", "pre"].contains(tag.name) {
                    var depth = 1, next = tag.end
                    while next < chars.count && depth > 0 {
                        if chars[next] == "<", let candidate = parseTag(chars, at: next) {
                            if candidate.name == tag.name { depth += candidate.closing ? -1 : 1 }
                            next = candidate.end
                        } else { next += 1 }
                    }
                    end = next
                }
                protected += prefix + String(tokens.count) + suffix
                tokens.append(String(chars[cursor..<end]))
                cursor = end
            } else { protected.append(chars[cursor]); cursor += 1 }
        }
        var result = markdown(protected)
        for (index, token) in tokens.enumerated() {
            result = result.replacingOccurrences(of: prefix + String(index) + suffix, with: token)
        }
        return result
    }

    private static func markdown(_ source: String, depth: Int = 0) -> String {
        guard depth < 8 else { return escaped(source) }
        let chars = Array(source)
        var result = "", buffer = "", cursor = 0
        func flush() { result += escaped(buffer); buffer = "" }
        while cursor < chars.count {
            if chars[cursor] == "\\", cursor + 1 < chars.count, "*_~`\\".contains(chars[cursor + 1]) {
                buffer.append(chars[cursor + 1]); cursor += 2; continue
            }
            var matched = false
            for (token, tag) in [("**", "strong"), ("__", "strong"), ("~~", "del"), ("*", "em"), ("_", "em")] {
                if starts(chars, at: cursor, with: token), let end = find(chars, from: cursor + token.count, token: token), end > cursor + token.count {
                    // Underscores inside identifiers are literal text.
                    if token.first == "_", cursor > 0, chars[cursor - 1].isLetter || chars[cursor - 1].isNumber { continue }
                    flush()
                    result += "<\(tag)>" + markdown(String(chars[(cursor + token.count)..<end]), depth: depth + 1) + "</\(tag)>"
                    cursor = end + token.count; matched = true; break
                }
            }
            if !matched { buffer.append(chars[cursor]); cursor += 1 }
        }
        flush(); return result
    }

    private static func escaped(_ source: String) -> String {
        let chars = Array(source)
        var output = "", index = 0
        while index < chars.count {
            let char = chars[index]
            if char == "&", let end = chars[(index + 1)...].firstIndex(of: ";"), end - index <= 32 {
                let name = String(chars[(index + 1)..<end])
                if name.range(of: #"^(?:[A-Za-z][A-Za-z0-9]*|#[0-9]{1,8}|#[xX][A-Fa-f0-9]{1,8})$"#, options: .regularExpression) != nil {
                    output += String(chars[index...end]); index = end + 1; continue
                }
            }
            switch char {
            case "&": output += "&amp;"
            case "<": output += "&lt;"
            case ">": output += "&gt;"
            case "\"": output += "&quot;"
            case "'": output += "&#39;"
            default: output.append(char)
            }
            index += 1
        }
        return output
    }
    private static func attributeEscape(_ source: String) -> String {
        source.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }
    private static func tagEnd(_ chars: [Character], from start: Int) -> Int? {
        var cursor = start, quote: Character?
        while cursor < chars.count {
            if let current = quote { if chars[cursor] == current { quote = nil } }
            else if chars[cursor] == "\"" || chars[cursor] == "'" { quote = chars[cursor] }
            else if chars[cursor] == ">" { return cursor }
            cursor += 1
        }
        return nil
    }
    private static func asciiLetter(_ char: Character) -> Bool { char.isASCII && char.isLetter }
    private static func starts(_ chars: [Character], at index: Int, with token: String) -> Bool {
        let target = Array(token)
        return index + target.count <= chars.count && Array(chars[index..<(index + target.count)]) == target
    }
    private static func find(_ chars: [Character], from start: Int, token: String) -> Int? {
        guard start < chars.count else { return nil }
        for index in start..<chars.count where starts(chars, at: index, with: token) { return index }
        return nil
    }
    private static func blockTags(in line: String) -> [(String, Bool)] {
        let chars = Array(line); var result: [(String, Bool)] = [], cursor = 0
        while cursor < chars.count {
            if chars[cursor] == "<", let tag = parseTag(chars, at: cursor) {
                if blocks.contains(tag.name) { result.append((tag.name, tag.closing)) }
                cursor = tag.end
            } else { cursor += 1 }
        }
        return result
    }
}
