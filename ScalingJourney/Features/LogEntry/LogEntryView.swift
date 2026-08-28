import PhotosUI
import SwiftUI

/// The log/edit sheet: weight, when, a photo, and an optional note.
struct LogEntryView: View {
    let mode: LogEntryMode

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var model: LogEntryViewModel?
    @State private var isPresentingCamera = false
    @State private var pickerSelection: PhotosPickerItem?
    @State private var isConfirmingDelete = false
    @FocusState private var isWeightFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    form(model)
                } else {
                    Color.sjBackground
                }
            }
            .background(Color.sjBackground)
            .navigationTitle(model?.title ?? "Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .presentationDragIndicator(.visible)
        .task {
            // Built here rather than in an initialiser so the view model can
            // take the environment's dependencies.
            guard model == nil else { return }
            model = LogEntryViewModel(
                mode: mode,
                journey: dependencies.journey,
                photoStore: dependencies.photoStore
            )
            // A beat before focusing, so the sheet's presentation animation is
            // not fighting the keyboard sliding up.
            try? await Task.sleep(for: .milliseconds(350))
            isWeightFieldFocused = true
        }
    }

    // MARK: Form

    @ViewBuilder
    private func form(_ model: LogEntryViewModel) -> some View {
        @Bindable var model = model

        ScrollView {
            VStack(spacing: Theme.Space.lg) {
                WeightField(
                    text: $model.weightText,
                    unit: model.entryUnit,
                    validationMessage: model.validationMessage,
                    isFocused: $isWeightFieldFocused
                )

                whenCard(model)

                PhotoAttachmentSection(
                    state: model.displayedPhotoState,
                    isProcessing: model.isProcessingPickedPhoto,
                    isCameraAvailable: CameraPicker.isAvailable,
                    suggestedDate: model.suggestedDateFromPhoto,
                    pickerSelection: $pickerSelection,
                    onTakePhoto: { isPresentingCamera = true },
                    onRemove: { model.removePhoto() },
                    onApplySuggestedDate: { model.applySuggestedDate() }
                )

                noteCard(model)

                if mode.isEditing {
                    Button("Delete Entry", role: .destructive) {
                        isConfirmingDelete = true
                    }
                    .font(.system(size: 16, weight: .medium))
                    .padding(.top, Theme.Space.xs)
                }
            }
            .padding(.horizontal, Theme.Space.screenHorizontal)
            .padding(.vertical, Theme.Space.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .fullScreenCover(isPresented: $isPresentingCamera) {
            CameraPicker { image in
                if let image { model.setCapturedImage(image) }
                isPresentingCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerSelection) { _, newValue in
            guard let newValue else { return }
            Task {
                await model.loadPickedPhoto(newValue)
                pickerSelection = nil
            }
        }
        .alert("Delete this entry?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    await model.delete()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The weight, photo and note for this entry will be removed. This cannot be undone.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            ),
            presenting: model.errorMessage
        ) { _ in
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    private func whenCard(_ model: LogEntryViewModel) -> some View {
        @Bindable var model = model

        return SJCard(padding: Theme.Space.md) {
            VStack(spacing: Theme.Space.xs) {
                DatePicker(
                    "Date",
                    selection: $model.measuredAt,
                    in: ...model.latestSelectableDate,
                    displayedComponents: .date
                )
                Divider().overlay(Color.sjSeparator)
                DatePicker(
                    "Time",
                    selection: $model.measuredAt,
                    in: ...model.latestSelectableDate,
                    displayedComponents: .hourAndMinute
                )
            }
            .font(.sjBody)
        }
    }

    private func noteCard(_ model: LogEntryViewModel) -> some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("Note")
                .sjLabelStyle()
                .padding(.leading, Theme.Space.xxs)

            SJCard(padding: Theme.Space.md) {
                TextField(
                    "How are you feeling? Anything worth remembering?",
                    text: $model.note,
                    axis: .vertical
                )
                .font(.sjBody)
                .lineLimit(3...6)
                .textInputAutocapitalization(.sentences)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                guard let model else { return }
                Task {
                    if await model.save() { dismiss() }
                }
            } label: {
                if model?.isSaving == true {
                    ProgressView()
                } else {
                    Text("Save").fontWeight(.semibold)
                }
            }
            .disabled(!(model?.canSave ?? false))
        }
    }
}

// MARK: - Weight field

/// The number is the point of the screen, so it is typed at hero size rather
/// than in a standard row-height text field.
private struct WeightField: View {
    @Binding var text: String
    var unit: MassUnit
    var validationMessage: String?
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            SJCard(padding: Theme.Space.xl) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Weight")
                        .sjLabelStyle()

                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                        TextField("0.0", text: $text)
                            .font(.sjHeroNumber)
                            .keyboardType(.decimalPad)
                            .focused($isFocused)
                            .foregroundStyle(Color.sjPrimaryText)
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityLabel("Weight in \(unit.displayName.lowercased())")

                        Text(unit.symbol)
                            .font(.sjHeroUnit)
                            .foregroundStyle(Color.sjSecondaryText)

                        Spacer(minLength: 0)
                    }
                }
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.sjCaption)
                    .foregroundStyle(.orange)
                    .padding(.leading, Theme.Space.xxs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Theme.Motion.quick, value: validationMessage)
    }
}
