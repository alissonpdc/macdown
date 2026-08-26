import Foundation

/// Extrai o caminho do arquivo a abrir dos argumentos CLI (`MacDown arquivo.md`).
/// Resolve caminho relativo para absoluto contra o diretório corrente.
public enum LaunchArgs {
    public static func fileURL(from arguments: [String] = CommandLine.arguments) -> URL? {
        guard let raw = arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) else { return nil }
        if raw.hasPrefix("file://"), let url = URL(string: raw) {
            return url
        }
        return URL(fileURLWithPath: raw).absoluteURL
    }
}
