import Foundation

/// Nome de exibição de arquivos — sempre com extensão (feedback do usuário).
public enum DisplayName {
    public static func file(_ url: URL) -> String {
        url.lastPathComponent
    }
}
