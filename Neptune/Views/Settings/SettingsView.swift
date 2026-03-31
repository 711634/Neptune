import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    petSettings
                    behaviorSettings
                    accessibilitySettings
                    aboutSection
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(hex: "111827"))
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(hex: "1F2937"))
    }

    private var petSettings: some View {
        settingsSection(title: "Pet") {
            VStack(alignment: .leading, spacing: 12) {
                settingRow(label: "Name") {
                    TextField("Pet name", text: $settings.petName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color(hex: "374151"))
                        .cornerRadius(6)
                        .frame(width: 150)
                }
            }
        }
    }

    private var behaviorSettings: some View {
        settingsSection(title: "Behavior") {
            VStack(alignment: .leading, spacing: 12) {
                settingRow(label: "Idle timeout") {
                    Picker("", selection: $settings.idleTimeoutMinutes) {
                        Text("1 min").tag(1)
                        Text("3 min").tag(3)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                settingRow(label: "Polling interval") {
                    Picker("", selection: $settings.pollingIntervalSeconds) {
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("5s").tag(5.0)
                        Text("10s").tag(10.0)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                settingRow(label: "Activity timeout") {
                    Picker("", selection: $settings.inactivityTimeoutSeconds) {
                        Text("10s").tag(10)
                        Text("20s").tag(20)
                        Text("30s").tag(30)
                        Text("60s").tag(60)
                        Text("2m").tag(120)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                Divider()
                    .background(Color(hex: "374151"))

                settingRow(label: "Sound effects") {
                    HStack(spacing: 6) {
                        Toggle("", isOn: $settings.soundEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(true)
                            .opacity(0.4)
                        Text("coming soon")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(hex: "6B7280"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "374151"))
                            .cornerRadius(3)
                    }
                }

                settingRow(label: "Use mock data") {
                    Toggle("", isOn: $settings.useMockData)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                settingRow(label: "Sync pet animations") {
                    Toggle("", isOn: $settings.syncPetAnimations)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
    }

    private var accessibilitySettings: some View {
        settingsSection(title: "Accessibility") {
            VStack(alignment: .leading, spacing: 12) {
                settingRow(label: "Reduced motion") {
                    Toggle("", isOn: $settings.reducedMotion)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Text("Reduces animations for users sensitive to motion.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "6B7280"))
            }
        }
    }

    private var aboutSection: some View {
        settingsSection(title: "About") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Neptune")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text("v1.0.0")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "6B7280"))
                }

                Text("A Tamagotchi-style companion for AI coding agents.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "9CA3AF"))

                Spacer().frame(height: 8)

                Button("Reset to Defaults") {
                    settings.reset()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "EF4444"))
            }
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "6B7280"))
                .tracking(1)

            content()
        }
        .padding(12)
        .background(Color(hex: "1F2937"))
        .cornerRadius(8)
    }

    private func settingRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "9CA3AF"))

            Spacer()

            content()
        }
    }
}
