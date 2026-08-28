import SwiftUI

/// Sets or clears the goal weight.
struct GoalEditorView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var hasLoaded = false
    @FocusState private var isFocused: Bool

    private var journey: JourneyStore { dependencies.journey }

    /// Stones are a display format only; the field takes pounds.
    private var entryUnit: MassUnit {
        journey.preferredUnit == .stones ? .pounds : journey.preferredUnit
    }

    private var parsedKilograms: Double? {
        WeightParser.kilograms(from: text, unit: entryUnit)
    }

    private var isCleared: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.md) {
                    SJCard(padding: Theme.Space.xl) {
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            Text("Goal weight")
                                .sjLabelStyle()

                            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                                TextField("0.0", text: $text)
                                    .font(.sjHeroNumber)
                                    .keyboardType(.decimalPad)
                                    .focused($isFocused)
                                    .fixedSize(horizontal: true, vertical: false)

                                Text(entryUnit.symbol)
                                    .font(.sjHeroUnit)
                                    .foregroundStyle(Color.sjSecondaryText)

                                Spacer(minLength: 0)
                            }
                        }
                    }

                    Text("Leave this empty to remove your goal. Progress is measured from your first recorded weight.")
                        .font(.sjCaption)
                        .foregroundStyle(Color.sjSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Space.xxs)
                }
                .padding(.horizontal, Theme.Space.screenHorizontal)
                .padding(.vertical, Theme.Space.lg)
            }
            .background(Color.sjBackground)
            .navigationTitle("Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await journey.setGoalWeight(kilograms: isCleared ? nil : parsedKilograms)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isCleared && parsedKilograms == nil)
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            if let goal = journey.profile?.goalWeightKilograms {
                text = WeightFormatter(unit: entryUnit).editingValue(fromKilograms: goal)
            }
            try? await Task.sleep(for: .milliseconds(350))
            isFocused = true
        }
    }
}
