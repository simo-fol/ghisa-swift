import Foundation

/// Small mutable XML tree (Foundation's XMLDocument is macOS only).
/// Names are kept as written ("c", "x:c"), so a parsed document is written back unchanged
/// apart from attribute order and the XML declaration.
final class XmlNode {
    enum Kind { case element, text, comment }

    let kind: Kind
    var name: String
    var attributes: [(String, String)]
    var children: [XmlNode] = []
    var text: String
    weak var parent: XmlNode?

    init(element name: String, attributes: [(String, String)] = []) {
        kind = .element
        self.name = name
        self.attributes = attributes
        text = ""
    }

    init(text: String, kind: Kind = .text) {
        self.kind = kind
        name = ""
        attributes = []
        self.text = text
    }

    /// Name without the namespace prefix.
    var localName: String {
        guard let colon = name.lastIndex(of: ":") else { return name }
        return String(name[name.index(after: colon)...])
    }

    /// Prefix with its colon ("x:"), or "" for the default namespace.
    var prefix: String {
        guard let colon = name.lastIndex(of: ":") else { return "" }
        return String(name[...colon])
    }

    var elements: [XmlNode] { children.filter { $0.kind == .element } }

    func elements(_ local: String) -> [XmlNode] { children.filter { $0.kind == .element && $0.localName == local } }

    func element(_ local: String) -> XmlNode? { children.first { $0.kind == .element && $0.localName == local } }

    func descendants(_ local: String) -> [XmlNode] {
        var found: [XmlNode] = []
        for child in elements {
            if child.localName == local { found.append(child) }
            found += child.descendants(local)
        }
        return found
    }

    /// Concatenated text of this node and everything below it.
    var value: String {
        kind == .text ? text : children.map { $0.kind == .comment ? "" : $0.value }.joined()
    }

    func attribute(_ name: String) -> String? { attributes.first { $0.0 == name }?.1 }

    /// Attribute by local name, whatever its prefix ("r:id" → "id").
    func attribute(local: String, prefixed: Bool) -> String? {
        attributes.first { key, _ in
            guard let colon = key.lastIndex(of: ":") else { return !prefixed && key == local }
            return prefixed && key[key.index(after: colon)...] == local
        }?.1
    }

    func setAttribute(_ name: String, _ value: String?) {
        if let i = attributes.firstIndex(where: { $0.0 == name }) {
            if let value { attributes[i].1 = value } else { attributes.remove(at: i) }
        } else if let value {
            attributes.append((name, value))
        }
    }

    func append(_ child: XmlNode) { insert(child, at: children.count) }

    func insert(_ child: XmlNode, at index: Int) {
        child.parent = self
        children.insert(child, at: index)
    }

    func insert(_ child: XmlNode, after sibling: XmlNode) {
        let i = children.firstIndex { $0 === sibling }.map { $0 + 1 } ?? children.count
        insert(child, at: i)
    }

    func removeChildren() { children.removeAll() }

    // MARK: Parse / serialize

    static func parse(_ data: Data) throws -> XmlNode {
        let builder = Builder()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        guard parser.parse(), let root = builder.root else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return root
    }

    func xmlData() -> Data {
        var out = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\r\n"
        write(into: &out)
        return Data(out.utf8)
    }

    private func write(into out: inout String) {
        switch kind {
        case .text:
            out += Self.escape(text, quotes: false)
        case .comment:
            out += "<!--\(text)-->"
        case .element:
            out += "<\(name)"
            for (key, value) in attributes { out += " \(key)=\"\(Self.escape(value, quotes: true))\"" }
            if children.isEmpty {
                out += "/>"
            } else {
                out += ">"
                for child in children { child.write(into: &out) }
                out += "</\(name)>"
            }
        }
    }

    static func escape(_ s: String, quotes: Bool) -> String {
        var r = ""
        r.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": r += "&amp;"
            case "<": r += "&lt;"
            case ">": r += "&gt;"
            case "\"" where quotes: r += "&quot;"
            case "\n" where quotes: r += "&#10;"
            case "\r": r += "&#13;"
            case "\t" where quotes: r += "&#9;"
            default: r.append(ch)
            }
        }
        return r
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: XmlNode?
        var stack: [XmlNode] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let node = XmlNode(element: qName ?? elementName,
                               attributes: attributeDict.sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
            if let parent = stack.last { parent.append(node) } else { root = node }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?) {
            stack.removeLast()
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { addText(string) }

        func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) { addText(whitespaceString) }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { addText(String(decoding: CDATABlock, as: UTF8.self)) }

        func parser(_ parser: XMLParser, foundComment comment: String) {
            stack.last?.append(XmlNode(text: comment, kind: .comment))
        }

        func addText(_ s: String) {
            guard let parent = stack.last else { return }
            // XMLParser may deliver one text run in several pieces.
            if let last = parent.children.last, last.kind == .text { last.text += s } else { parent.append(XmlNode(text: s)) }
        }
    }
}
