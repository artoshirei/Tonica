import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    let controller: AppController

    @State private var selectedTheme: PanelTheme

    init(controller: AppController) {
        self.controller = controller
        _selectedTheme = State(initialValue: controller.model.theme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            SettingsCard(
                title: "Appearance",
                subtitle: "Choose the panel finish that feels best in your workspace."
            ) {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(PanelTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: selectedTheme) { _, newValue in
                    controller.updateTheme(newValue)
                }
            }

            SettingsCard(
                title: "Shortcut",
                subtitle: "Use one toggle to reveal the circle, then press it again to hide it."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                        .frame(maxWidth: 220, alignment: .leading)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("Current shortcut")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(controller.model.shortcutDescription)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }

                    Button("Restore Default") {
                        controller.resetHotKeyToDefault()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
        .padding(24)
        .frame(width: 470)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            ApplicationIconView()
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 5) {
                Text("Tonica")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Clean shortcuts, quick key lookup, and a calmer harmony workflow.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ApplicationIconView: View {
    private let iconImage = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

    var body: some View {
        Image(nsImage: iconImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.06))
        }
    }
}
