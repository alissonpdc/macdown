import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeState

    var body: some View {
        Form {
            Picker("Tema", selection: $theme.current) {
                Text("Claro").tag(AppTheme.light)
                Text("Escuro").tag(AppTheme.dark)
                Text("Sistema").tag(AppTheme.system)
            }
            .pickerStyle(.inline)
        }
        .padding(20)
        .frame(width: 360)
    }
}
