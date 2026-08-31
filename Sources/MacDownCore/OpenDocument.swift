import Foundation

public enum OpenDocumentError: Error, Equatable {
    case readFailed
}

/// Um arquivo `.md` aberto: URL + frontmatter extraído (R3.4/R10.2) + corpo parseado.
public struct OpenDocument: Equatable {
    public let url: URL
    public let rawText: String
    public let frontmatter: Frontmatter?
    public let frontmatterError: String?
    public let document: CoreDocument

    public static func == (a: OpenDocument, b: OpenDocument) -> Bool {
        a.url == b.url && a.rawText == b.rawText
    }

    public init(url: URL) throws {
        let resolved = url.resolvingSymlinksInPath()
        guard let text = try? String(contentsOf: resolved, encoding: .utf8) else {
            throw OpenDocumentError.readFailed
        }
        self.init(url: resolved, rawText: text)
    }

    public init(url: URL, rawText: String) {
        self.url = url
        self.rawText = rawText
        let result = FrontmatterExtractor.extract(from: rawText)
        self.frontmatter = result.frontmatter
        self.frontmatterError = result.error
        self.document = MarkdownParser().parse(result.markdown)
    }

    public var wordCount: Int {
        PlainTextExtractor.extract(from: document).split(whereSeparator: \.isWhitespace).count
    }

    public var characterCount: Int { rawText.count }
}
