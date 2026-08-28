import Foundation

/// R3.5 — resolve href relativo contra o arquivo que contém o link.
/// Retorna nil para âncoras puras (#secao) e URLs externas.
public enum LinkResolver {
    public static func resolve(href: String, from sourceFile: URL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { return nil }
        guard let url = URL(string: trimmed) ?? URL(fileURLWithPath: trimmed).absoluteURL as URL? else { return nil }
        if url.scheme != nil && url.scheme != "file" { return nil }

        let base = sourceFile.deletingLastPathComponent()
        var resolved = trimmed.hasPrefix("/") ? URL(fileURLWithPath: trimmed) : URL(fileURLWithPath: trimmed, relativeTo: base)
        resolved = resolved.standardizedFileURL
        // remove fragmento/âncora
        return URL(fileURLWithPath: resolved.path)
    }
}
