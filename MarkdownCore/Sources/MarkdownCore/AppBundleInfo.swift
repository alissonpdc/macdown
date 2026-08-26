import Foundation

/// Gera os arquivos do bundle .app (Info.plist) para empacotar o executável.
public enum AppBundleInfo {
    public static let bundleIdentifier = "com.macdown.app"
    public static let version = "0.1.0"

    public static var infoPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key><string>\(bundleIdentifier)</string>
            <key>CFBundleName</key><string>MacDown</string>
            <key>CFBundleExecutable</key><string>MacDown</string>
            <key>CFBundlePackageType</key><string>APPL</string>
            <key>CFBundleShortVersionString</key><string>\(version)</string>
            <key>CFBundleVersion</key><string>\(version)</string>
            <key>LSMinimumSystemVersion</key><string>14.0</string>
            <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
            <key>NSHighResolutionCapable</key><true/>
            <key>CFBundleDocumentTypes</key>
            <array>
                <dict>
                    <key>CFBundleTypeName</key><string>Markdown Document</string>
                    <key>CFBundleTypeRole</key><string>Viewer</string>
                    <key>LSItemContentTypes</key>
                    <array>
                        <string>net.daringfireball.markdown</string>
                        <string>com.unknown.md</string>
                        <string>public.text</string>
                    </array>
                    <key>CFBundleTypeExtensions</key>
                    <array>
                        <string>md</string>
                        <string>markdown</string>
                        <string>mdown</string>
                        <string>mkd</string>
                    </array>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }
}
