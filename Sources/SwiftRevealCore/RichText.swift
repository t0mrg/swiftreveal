import Foundation

/// A conservative rich-text renderer. It reconstructs an explicit HTML allowlist,
/// never passes source tags through, and does not permit resource URLs or inline CSS.
public enum RichText {
    public static func inline(_ source: String) -> String { sanitize(source, allowBlocks: false) }

    public static func body(_ source: String) -> String {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let safe = sanitize(normalized, allowBlocks: true)
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
            if allowBlocks, suppressed.isEmpty, !stack.contains("pre"), !stack.contains("code"),
               (index == 0 || chars[index - 1] == "\n"), let fence = fencedCode(chars, at: index) {
                flush()
                if let paragraph = stack.lastIndex(of: "p") {
                    for name in stack[paragraph...].reversed() { output += "</\(name)>" }
                    stack.removeSubrange(paragraph...)
                }
                output += fence.html + "\n"
                index = fence.end
                continue
            }
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
                output += "<code>" + attributeEscape(String(chars[(index + 1)..<close])) + "</code>"
                index = close + 1
                continue
            }
            buffer.append(chars[index]); index += 1
        }
        flush()
        for name in stack.reversed() { output += "</\(name)>" }
        return markdownAcrossMarkup(output)
    }

    /// Fences are parsed before HTML, while still respecting suppressed HTML
    /// containers and literal <pre>/<code>. Code never enters the HTML sanitizer
    /// as source markup: output consists of balanced wrappers and escaped tokens.
    private static func fencedCode(_ chars: [Character], at start: Int) -> (html: String, end: Int)? {
        var cursor = start, indentation = 0
        while cursor < chars.count && chars[cursor] == " " && indentation < 4 { cursor += 1; indentation += 1 }
        guard indentation <= 3, cursor < chars.count, chars[cursor] == "`" || chars[cursor] == "~" else { return nil }
        let marker = chars[cursor], markerStart = cursor
        while cursor < chars.count && chars[cursor] == marker { cursor += 1 }
        let width = cursor - markerStart
        guard width >= 3 else { return nil }
        let infoStart = cursor
        while cursor < chars.count && chars[cursor] != "\n" { cursor += 1 }
        let info = String(chars[infoStart..<cursor]).trimmingCharacters(in: .whitespaces)
        guard marker != "`" || !info.contains("`") else { return nil }
        let language = codeLanguage(info.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "")
        let contentStart = cursor < chars.count ? cursor + 1 : cursor
        var lineStart = contentStart, contentEnd = chars.count, end = chars.count
        while lineStart < chars.count {
            var lineEnd = lineStart
            while lineEnd < chars.count && chars[lineEnd] != "\n" { lineEnd += 1 }
            var candidate = lineStart, spaces = 0
            while candidate < lineEnd && chars[candidate] == " " && spaces < 4 { candidate += 1; spaces += 1 }
            let runStart = candidate
            while candidate < lineEnd && chars[candidate] == marker { candidate += 1 }
            if spaces <= 3 && candidate - runStart >= width && chars[candidate..<lineEnd].allSatisfy({ $0 == " " || $0 == "\t" }) {
                contentEnd = lineStart; end = lineEnd < chars.count ? lineEnd + 1 : lineEnd; break
            }
            lineStart = lineEnd < chars.count ? lineEnd + 1 : lineEnd
        }
        var code = String(chars[contentStart..<contentEnd])
        if indentation > 0 {
            code = code.components(separatedBy: "\n").map { line in
                var line = line, removed = 0
                while removed < indentation && line.first == " " { line.removeFirst(); removed += 1 }
                return line
            }.joined(separator: "\n")
        }
        let className = language.isEmpty ? "" : " class=\"language-\(language)\""
        return ("<pre class=\"sr-code\"><code\(className)>\(highlight(code, language: language))</code></pre>", end)
    }

    private static func codeLanguage(_ info: String) -> String {
        let raw = info.lowercased()
        guard raw.count <= 40, raw.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "_+#.-".contains($0)) }) else { return "" }
        return ["py": "python", "python3": "python", "rscript": "r", "js": "javascript", "jsx": "javascript", "ts": "typescript", "tsx": "typescript", "sh": "bash", "shell": "bash", "zsh": "bash", "c++": "cpp", "c#": "csharp", "cs": "csharp", "yml": "yaml", "htm": "html", "xml": "html", "text": "plaintext", "txt": "plaintext" ][raw] ?? raw
    }

    /// Small deterministic lexical highlighter, intentionally avoiding runtime
    /// scripts and guessed languages. Unknown languages remain literal code.
    private static func highlight(_ source: String, language: String) -> String {
        let keywords: [String: Set<String>] = [
            "python": Set("and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield match case".split(separator: " ").map(String.init)),
            "r": Set("if else repeat while function for in next break TRUE FALSE NULL Inf NaN NA NA_integer_ NA_real_ NA_complex_ NA_character_".split(separator: " ").map(String.init)),
            "swift": Set("actor any as associatedtype async await borrowing break case catch class consuming continue convenience default defer deinit didSet do dynamic else enum extension fallthrough false fileprivate final for func get guard if import in indirect init inout internal is isolated lazy let mutating nil nonisolated nonmutating open operator override package private protocol public repeat required rethrows return self Self set some static struct subscript super switch throws throw true try typealias unowned var weak where while willSet".split(separator: " ").map(String.init)),
            "javascript": Set("as async await break case catch class const continue debugger default delete do else export extends false finally for from function get if import in instanceof let new null of return set static super switch this throw true try typeof undefined var void while with yield".split(separator: " ").map(String.init)),
            "typescript": Set("abstract any as async await boolean break case catch class const constructor continue declare default delete do else enum export extends false finally for from function get if implements import in infer instanceof interface is keyof let namespace never new null number of private protected public readonly return set static string super switch symbol this throw true try type typeof undefined unique unknown var void while with yield".split(separator: " ").map(String.init)),
            "sql": Set("select from where join inner outer left right full on as group by order having limit offset union all distinct with recursive insert into values update set delete create alter drop table view index and or not null true false is in exists between like case when then else end asc desc over partition count sum avg min max".split(separator: " ").map(String.init)),
            "bash": Set("if then else elif fi for while until do done case esac in function select time coproc break continue return export local readonly declare typeset source".split(separator: " ").map(String.init)),
            "json": ["true", "false", "null"],
            "yaml": ["true", "false", "null", "yes", "no"],
            "c": Set("auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while _Bool".split(separator: " ").map(String.init)),
            "cpp": Set("alignas alignof auto bool break case catch char class concept const constexpr continue decltype default delete do double else enum explicit export extern false float for friend if inline int long namespace new noexcept nullptr operator private protected public register requires return short signed sizeof static struct switch template this thread_local throw true try typedef typename union unsigned using virtual void volatile wchar_t while".split(separator: " ").map(String.init)),
            "csharp": Set("abstract as async await base bool break byte case catch char checked class const continue decimal default delegate do double else enum event explicit extern false finally fixed float for foreach if implicit in int interface internal is lock long namespace new null object operator out override params private protected public readonly record ref return sbyte sealed short sizeof stackalloc static string struct switch this throw true try typeof uint ulong unchecked unsafe ushort using var virtual void volatile while yield".split(separator: " ").map(String.init)),
            "java": Set("abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new null package private protected public record return short static strictfp super switch synchronized this throw throws transient true false try var void volatile while".split(separator: " ").map(String.init)),
            "go": Set("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var true false nil".split(separator: " ").map(String.init)),
            "rust": Set("as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while".split(separator: " ").map(String.init)),
            "html": [], "css": []
        ]
        guard let words = keywords[language] else { return attributeEscape(source) }
        let chars = Array(source)
        var cursor = 0, output = ""
        let hashComments = ["python", "r", "bash", "yaml"].contains(language)
        let slashComments = ["swift", "javascript", "typescript", "c", "cpp", "csharp", "java", "go", "rust"].contains(language)
        func emit(_ start: Int, _ end: Int, _ type: String? = nil) {
            let text = attributeEscape(String(chars[start..<end]))
            output += type.map { "<span class=\"sr-token-\($0)\">\(text)</span>" } ?? text
        }
        while cursor < chars.count {
            let start = cursor, char = chars[cursor]
            if (hashComments && char == "#") || (slashComments && starts(chars, at: cursor, with: "//")) || (language == "sql" && starts(chars, at: cursor, with: "--")) {
                while cursor < chars.count && chars[cursor] != "\n" { cursor += 1 }
                emit(start, cursor, "comment")
            } else if (slashComments || language == "css" || language == "sql") && starts(chars, at: cursor, with: "/*") {
                cursor = find(chars, from: cursor + 2, token: "*/").map { $0 + 2 } ?? chars.count
                emit(start, cursor, "comment")
            } else if language == "html" && starts(chars, at: cursor, with: "<!--") {
                cursor = find(chars, from: cursor + 4, token: "-->").map { $0 + 3 } ?? chars.count
                emit(start, cursor, "comment")
            } else if language == "html" && char == "<" {
                cursor = tagEnd(chars, from: cursor + 1).map { $0 + 1 } ?? chars.count
                emit(start, cursor, "keyword")
            } else if char == "\"" || char == "'" || (["javascript", "typescript", "bash"].contains(language) && char == "`") {
                let triple = (language == "python" || language == "swift") && starts(chars, at: cursor, with: String(repeating: String(char), count: 3))
                let delimiter = String(repeating: String(char), count: triple ? 3 : 1)
                cursor += delimiter.count
                while cursor < chars.count {
                    if chars[cursor] == "\\" { cursor = min(chars.count, cursor + 2) }
                    else if starts(chars, at: cursor, with: delimiter) { cursor += delimiter.count; break }
                    else { cursor += 1 }
                }
                emit(start, cursor, "string")
            } else if char.isASCII && char.isNumber {
                cursor += 1
                while cursor < chars.count {
                    let current = chars[cursor]
                    if current.isASCII && (current.isNumber || current.isLetter || current == "_" || current == ".") { cursor += 1 }
                    else if (current == "+" || current == "-") && (chars[cursor - 1] == "e" || chars[cursor - 1] == "E") { cursor += 1 }
                    else { break }
                }
                emit(start, cursor, "number")
            } else if char.isLetter || char == "_" || char == "$" {
                cursor += 1
                while cursor < chars.count && (chars[cursor].isLetter || chars[cursor].isNumber || chars[cursor] == "_" || chars[cursor] == "$" || language == "r" && chars[cursor] == ".") { cursor += 1 }
                let word = String(chars[start..<cursor])
                var lookahead = cursor
                while lookahead < chars.count && (chars[lookahead] == " " || chars[lookahead] == "\t") { lookahead += 1 }
                let type: String?
                if words.contains(language == "sql" ? word.lowercased() : word) { type = "keyword" }
                else if lookahead < chars.count && chars[lookahead] == "(" { type = "function" }
                else if language == "css" && lookahead < chars.count && chars[lookahead] == ":" { type = "keyword" }
                else if char.isUppercase || language == "bash" && char == "$" { type = "type" }
                else { type = nil }
                emit(start, cursor, type)
            } else { cursor += 1; emit(start, cursor) }
        }
        return output
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
