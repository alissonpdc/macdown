// Gera Info.plist no bundle .app — chamado pelo Makefile.
// Uso: swift run plistgen <caminho-do-Info.plist-de-destino>
import Foundation
import MarkdownCore

let args = CommandLine.arguments
let output = args.count > 1 ? args[1] : "Info.plist"
try AppBundleInfo.infoPlist.write(toFile: output, atomically: true, encoding: .utf8)
print("Info.plist gerado em \(output)")
