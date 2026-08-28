import SwiftUI

/// Account, preferences and privacy.
///
/// Rows for features that do not exist yet are deliberately absent rather than
/// present-and-disabled: a greyed-out "Import CSV" reads as broken software.
/// They appear as they are built.
struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var isPresentingGoalEditor = false

    private var journey: JourneyStore { dependencies.journey }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                preferencesSection
                goalSection
                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isPresentingGoalEditor) {
                GoalEditorView()
            }
        }
    }

    // MARK: Account

    @ViewBuilder
    private var accountSection: some View {
        Section {
            LabeledContent("Signed in with") {
                Text(dependencies.auth.state.account?.provider.displayName ?? "Not signed in")
            }
        } header: {
            Text("Account")
        } footer: {
            if dependencies.auth.needsCloudAccount {
                Text("Your journey is stored on this device only. Creating an account will let you sign in on another device and recover your entries and photos. Accounts are coming in a future update.")
            }
        }
    }

    // MARK: Preferences

    private var preferencesSection: some View {
        Section {
            Picker("Units", selection: unitBinding) {
                ForEach(MassUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
        } header: {
            Text("Preferences")
        } footer: {
            Text("Weights are always stored precisely, so switching units never changes a recorded value.")
        }
    }

    private var unitBinding: Binding<MassUnit> {
        Binding(
            get: { journey.preferredUnit },
            set: { newValue in Task { await journey.setPreferredUnit(newValue) } }
        )
    }

    // MARK: Goal

    private var goalSection: some View {
        Section("Goal") {
            Button {
                isPresentingGoalEditor = true
            } label: {
                LabeledContent("Goal weight") {
                    Text(goalDescription)
                        .foregroundStyle(Color.sjSecondaryText)
                }
            }
            .tint(Color.sjPrimaryText)
        }
    }

    private var goalDescription: String {
        guard let goal = journey.profile?.goalWeightKilograms else { return "Not set" }
        return journey.formatter.string(fromKilograms: goal)
    }

    // MARK: Privacy

    private var privacySection: some View {
        Section {
            NavigationLink("How your data is handled") {
                PrivacyDetailView()
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Scaling Journey has no social features and no public profiles. Nothing is ever shared automatically.")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Self.versionString)
            if dependencies.isRunningEphemerally {
                Label("Storage unavailable", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

// MARK: - Privacy detail

/// Plain-language explanation of where the data goes.
///
/// The app asks people to photograph their bodies. Saying clearly and
/// specifically what happens to those images is part of earning that, not
/// legal boilerplate to be buried in a website.
private struct PrivacyDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                paragraph(
                    title: "Your photos stay on this device",
                    body: "Progress photos are saved inside the app's private storage. They are not added to your photo library, not included in device backups, and not uploaded anywhere. They are readable only after you have unlocked this device."
                )
                paragraph(
                    title: "Nothing is shared automatically",
                    body: "There are no profiles, no feeds and no sharing features. Nothing leaves this device unless you explicitly export it."
                )
                paragraph(
                    title: "The camera is used only when you ask",
                    body: "The camera opens only when you tap Take Photo, and captures only the single image you take."
                )
                paragraph(
                    title: "You can delete everything",
                    body: "Deleting an entry removes its weight, note and photo file together. Full data export and account deletion arrive alongside cloud accounts."
                )
            }
            .padding(Theme.Space.screenHorizontal)
        }
        .background(Color.sjBackground)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func paragraph(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.sjPrimaryText)
            Text(body)
                .font(.sjBody)
                .foregroundStyle(Color.sjSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
