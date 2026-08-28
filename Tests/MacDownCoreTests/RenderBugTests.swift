import XCTest
@testable import MacDownCore

final class RenderBugTests: XCTestCase {
    let converter = MarkdownHTMLConverter()

    private func freshDefaults() -> UserDefaults {
        let name = "test.renderbug.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    // MARK: - Bug: Bold/inline code lost in list items

    func testBoldInListItemPreserved() {
        let input = """
        - **R1.1** — App aberto diretamente
        - **R1.2** — Registro como app padrão
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<strong>R1.1</strong>"), "Bold R1.1 should be preserved in list item")
        XCTAssertTrue(html.contains("<strong>R1.2</strong>"), "Bold R1.2 should be preserved in list item")
    }

    func testInlineCodeInListItemPreserved() {
        let input = """
        - Arquivo `.md` no Finder
        - Pasta `~/Documents`
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<code>.md</code>"), "Inline code .md should be preserved in list item")
        XCTAssertTrue(html.contains("<code>~/Documents</code>"), "Inline code ~/Documents should be preserved")
    }

    func testBoldAndCodeTogetherInListItem() {
        let input = """
        - **R1.1** — Selecione arquivo `.md`
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<strong>R1.1</strong>"), "Bold should be preserved")
        XCTAssertTrue(html.contains("<code>.md</code>"), "Inline code should be preserved")
    }

    func testListItemWithEmDashAndBold() {
        let input = """
        - **R1.1** — App aberto diretamente (sem arquivo): exibe um diálogo/popup para selecionar um arquivo ou pasta `.md`.
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<strong>R1.1</strong>"), "Bold should render")
        XCTAssertTrue(html.contains("—"), "Em dash should be present")
        XCTAssertTrue(html.contains("<code>.md</code>"), "Inline code should render")
    }

    // MARK: - Bug: Task list checkboxes lost

    func testTaskListCheckboxesRendered() {
        let input = """
        - [x] Split frontmatter antes do parse
        - [x] YAML mínimo: chaves, valores, listas
        - [ ] NSDocument abrir arquivo único
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("task-list"), "Should have task-list class")
        XCTAssertTrue(html.contains("<input type=\"checkbox\" checked"), "Checked item should have checked attribute")
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled>"), "Unchecked item should have disabled checkbox")
        XCTAssertTrue(html.contains("Split frontmatter"), "Task text should be preserved")
        XCTAssertTrue(html.contains("NSDocument"), "Unchecked item text should be preserved")
    }

    func testTaskListItemCount() {
        let input = """
        - [x] Item 1
        - [ ] Item 2
        - [x] Item 3
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)
        let inputCount = html.components(separatedBy: "<input").count - 1
        XCTAssertEqual(inputCount, 3, "Should have 3 checkbox inputs")
    }

    func testTaskListHTMLStructure() {
        let input = """
        - [x] Done item
        - [ ] Todo item
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)
        // Check exact HTML structure
        XCTAssertTrue(html.contains("<ul class=\"task-list\">"), "Should have task-list ul")
        XCTAssertTrue(html.contains("<li class=\"task-item\">"), "Should have task-item li")
        XCTAssertTrue(html.contains("<input type=\"checkbox\" checked disabled>"), "Checked item: checkbox checked disabled")
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled>"), "Unchecked item: checkbox disabled only")
        // Make sure text comes after checkbox, wrapped in a single task-text span
        XCTAssertTrue(html.contains("checked disabled><span class=\"task-text\">Done item</span></li>"), "Done item text after checkbox")
        XCTAssertTrue(html.contains("disabled><span class=\"task-text\">Todo item</span></li>"), "Todo item text after checkbox")
    }

    // MARK: - Bug: Heading rendering

    func testHeadingRendersAsHeading() {
        let input = """
        ### 4.1 Abertura de arquivos

        - **R1.1** — App aberto diretamente
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)
        XCTAssertTrue(html.contains("<h3"), "Should render as h3 heading")
        XCTAssertTrue(html.contains("4.1 Abertura de arquivos"), "Heading text should be present")
    }

    // MARK: - Bug: zoom breaks central column layout

    func testColumnWidthStableAcrossZoomLevels() {
        let prefsLow = ReadingPrefs(defaults: freshDefaults())
        prefsLow.fontSize = 12
        prefsLow.widthCh = 70

        let prefsHigh = ReadingPrefs(defaults: freshDefaults())
        prefsHigh.fontSize = 24
        prefsHigh.widthCh = 70

        let headerLow = MarkdownHTMLConverter.htmlHeader(readingPrefs: prefsLow)
        let headerHigh = MarkdownHTMLConverter.htmlHeader(readingPrefs: prefsHigh)

        // Body font-size must always be 16px (layout baseline), not the zoomed value
        XCTAssertTrue(headerLow.contains("font-size: 16px;"), "Body font-size must be fixed 16px at low zoom")
        XCTAssertTrue(headerHigh.contains("font-size: 16px;"), "Body font-size must be fixed 16px at high zoom")

        // --reading-font-size must reflect the zoomed value (Double prints as "12.0")
        XCTAssertTrue(headerLow.contains("--reading-font-size: 12.0px;"), "CSS var should reflect zoom level (12)")
        XCTAssertTrue(headerHigh.contains("--reading-font-size: 24.0px;"), "CSS var should reflect zoom level (24)")

        // --reading-width must use ch units (stable at body's fixed 16px)
        XCTAssertTrue(headerLow.contains("--reading-width: 70"), "Column width should be 70ch")
        XCTAssertTrue(headerHigh.contains("--reading-width: 70"), "Column width should stay 70ch regardless of zoom")
        XCTAssertTrue(headerLow.contains("ch;"), "Column width should use ch units")
        XCTAssertTrue(headerHigh.contains("ch;"), "Column width should use ch units")
    }

    func testBodyUsesFixedFontSizeForChStability() {
        let prefs = ReadingPrefs(defaults: freshDefaults())
        prefs.fontSize = 20

        let header = MarkdownHTMLConverter.htmlHeader(readingPrefs: prefs)

        // body must have fixed 16px, NOT var(--reading-font-size)
        // Find the body rule and check its font-size
        let bodyStart = header.range(of: "body {")
        XCTAssertNotNil(bodyStart, "Should have body rule")
        if let bodyStart = bodyStart {
            let bodySection = String(header[bodyStart.lowerBound...].prefix(300))
            XCTAssertTrue(bodySection.contains("font-size: 16px;"),
                          "body must use fixed 16px font-size for ch-unit stability")
            XCTAssertFalse(bodySection.contains("font-size: var(--reading-font-size"),
                           "body must not use --reading-font-size for its font-size")
        }

        // body > * must apply the zoomed font-size
        XCTAssertTrue(header.contains("body > *"), "Should have body > * rule")
        let childStart = header.range(of: "body > *")
        XCTAssertNotNil(childStart)
        if let childStart = childStart {
            let childSection = String(header[childStart.lowerBound...].prefix(200))
            XCTAssertTrue(childSection.contains("font-size: var(--reading-font-size, 16px)"),
                          "body > * must apply --reading-font-size for zoom")
        }
    }

    func testColumnCenteredWithMarginAuto() {
        let header = MarkdownHTMLConverter.htmlHeader()
        XCTAssertTrue(header.contains("margin: 0 auto;"), "body should use margin: 0 auto for centering")
        // body rule must not have display: flex (flex may still appear in .code-header etc.)
        let bodyStart = header.range(of: "body {")
        XCTAssertNotNil(bodyStart)
        if let bodyStart = bodyStart {
            let bodySection = String(header[bodyStart.lowerBound...].prefix(400))
            XCTAssertFalse(bodySection.contains("display: flex;"),
                           "body rule should not use flex layout")
        }
    }

    // MARK: - Full document regression

    func testFullDocumentWithHeadingsListsAndTaskLists() {
        let input = """
        ### 4.1 Abertura de arquivos

        - **R1.1** — App aberto diretamente (sem arquivo): exibe um diálogo/popup para selecionar um arquivo ou pasta `.md`.
        - **R1.2** — Registro como app padrão (ou opção "Abrir com") para arquivos `.md`: duplo-clique no Finder abre direto no MacDown.

        ### Fase 2 — Documento

        - [x] Split frontmatter antes do parse
        - [x] YAML mínimo: chaves, valores, listas (R3.4 base)
        - [x] YAML malformado / não-suportado → erro estruturado (R10.2)
        - [ ] NSDocument abrir arquivo único (R1.1, R1.2 base)
        """
        let doc = MarkdownParser().parse(input)
        let html = converter.convert(doc)

        // Headings
        XCTAssertTrue(html.contains("<h3"), "Should have h3 headings")

        // Bold in list items
        XCTAssertTrue(html.contains("<strong>R1.1</strong>"), "Bold R1.1 in list")
        XCTAssertTrue(html.contains("<strong>R1.2</strong>"), "Bold R1.2 in list")

        // Inline code in list items
        XCTAssertTrue(html.contains("<code>.md</code>"), "Inline code .md in list")

        // Task list checkboxes
        XCTAssertTrue(html.contains("checkbox"), "Should have checkboxes")
        XCTAssertTrue(html.contains("task-list"), "Should have task-list class")

        // Task list items count
        let inputCount = html.components(separatedBy: "<input").count - 1
        XCTAssertEqual(inputCount, 4, "Should have 4 checkbox inputs")
    }
}
