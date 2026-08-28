import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Whether the sheet is creating a new entry or editing an existing one.
enum LogEntryMode: Hashable {
    case create(date: Date)
    case edit(WeightEntrySnapshot)

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }

    var existingEntry: WeightEntrySnapshot? {
        if case .edit(let entry) = self { return entry }
        return nil
    }
}

/// Drives the log/edit sheet: field state, validation and saving.
///
/// Kept separate from the view so the save sequence — which writes an image to
/// disk and then a database row, and has to clean up if the second half fails —
/// is readable and testable rather than buried in a button action.
@MainActor
@Observable
final class LogEntryViewModel {
    // MARK: Form state

    var weightText: String = ""
    var measuredAt: Date = .now
    var note: String = ""

    /// A newly chosen image not yet written to storage.
    var pendingImage: UIImage?
    /// Capture date of `pendingImage`, read from EXIF when available.
    private(set) var pendingImageCaptureDate: Date?

    /// The photo already attached to the entry being edited.
    private(set) var existingPhoto: PhotoSnapshot?
    /// Set when the user removes an existing photo without choosing a new one.
    private(set) var removesExistingPhoto = false

    private(set) var isSaving = false
    private(set) var isProcessingPickedPhoto = false
    var errorMessage: String?

    let mode: LogEntryMode
    private let journey: JourneyStore
    private let photoStore: any PhotoStore

    init(mode: LogEntryMode, journey: JourneyStore, photoStore: any PhotoStore) {
        self.mode = mode
        self.journey = journey
        self.photoStore = photoStore

        switch mode {
        case .create(let date):
            self.measuredAt = date
            // Prefill with the most recent weight. Day-to-day change is small,
            // so starting from the last value means a couple of taps instead of
            // typing the whole number, and it anchors the user if they are
            // unsure what they last weighed.
            if let latest = journey.statistics.currentWeightKilograms {
                self.weightText = Self.editingText(forKilograms: latest, unit: journey.preferredUnit)
            }
        case .edit(let entry):
            self.measuredAt = entry.measuredAt
            self.weightText = Self.editingText(forKilograms: entry.weightKilograms, unit: journey.preferredUnit)
            self.note = entry.note ?? ""
            self.existingPhoto = entry.photo
        }
    }

    // MARK: Derived

    var unit: MassUnit { journey.preferredUnit }

    /// The unit the text field accepts.
    ///
    /// Stones are a *display* format — nobody types "12.3 st" on a keypad, they
    /// think in pounds. So a stones user reads `12 st 4.2 lb` everywhere but
    /// enters plain pounds here.
    var entryUnit: MassUnit { unit == .stones ? .pounds : unit }

    var title: String { mode.isEditing ? "Edit Entry" : "Log Weight" }

    /// Parsed weight in kilograms, or `nil` when the field is not yet valid.
    var parsedKilograms: Double? {
        WeightParser.kilograms(from: weightText, unit: entryUnit)
    }

    /// Prefill text in whichever unit the field accepts.
    private static func editingText(forKilograms kilograms: Double, unit: MassUnit) -> String {
        let entryUnit: MassUnit = unit == .stones ? .pounds : unit
        return WeightFormatter(unit: entryUnit).editingValue(fromKilograms: kilograms)
    }

    var canSave: Bool { parsedKilograms != nil && !isSaving }

    /// Inline validation message, shown only once the user has typed something
    /// so an empty field on open does not look like an error.
    var validationMessage: String? {
        let trimmed = weightText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, parsedKilograms == nil else { return nil }
        return "Enter a weight between \(Int(WeightParser.plausibleKilograms.lowerBound)) and \(Int(WeightParser.plausibleKilograms.upperBound)) kg."
    }

    /// The photo currently represented by the form, whichever source it is from.
    var displayedPhotoState: PhotoState {
        if let pendingImage { return .pending(pendingImage) }
        if let existingPhoto, !removesExistingPhoto { return .stored(existingPhoto) }
        return .none
    }

    enum PhotoState {
        case none
        case pending(UIImage)
        case stored(PhotoSnapshot)

        var hasPhoto: Bool {
            if case .none = self { return false }
            return true
        }
    }

    /// Entries cannot be dated in the future: a progress journal is a record of
    /// what happened, and a future-dated row corrupts every trend calculation.
    var latestSelectableDate: Date { .now }

    // MARK: Photo selection

    func setCapturedImage(_ image: UIImage) {
        pendingImage = image
        pendingImageCaptureDate = .now
        removesExistingPhoto = false
    }

    /// Loads a photo picked from the library and reads its capture date.
    ///
    /// If the photo was taken on a different day than the entry, the date is
    /// *not* changed silently — the view offers it as a suggestion. Quietly
    /// re-dating someone's entry is exactly the kind of surprise this app
    /// should never spring.
    func loadPickedPhoto(_ item: PhotosPickerItem) async {
        isProcessingPickedPhoto = true
        defer { isProcessingPickedPhoto = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                errorMessage = "That photo could not be opened."
                return
            }
            pendingImage = image
            pendingImageCaptureDate = ImageMetadata.captureDate(from: data)
            removesExistingPhoto = false
        } catch {
            AppLog.photos.error("Picked photo load failed: \(String(describing: error))")
            errorMessage = "That photo could not be opened."
        }
    }

    /// The photo's own capture date, when it differs from the entry's date by
    /// more than a day and is therefore worth offering.
    var suggestedDateFromPhoto: Date? {
        guard let captured = pendingImageCaptureDate, captured <= latestSelectableDate else { return nil }
        guard !Calendar.current.isDate(captured, inSameDayAs: measuredAt) else { return nil }
        return captured
    }

    func applySuggestedDate() {
        guard let suggested = suggestedDateFromPhoto else { return }
        measuredAt = suggested
    }

    func removePhoto() {
        pendingImage = nil
        pendingImageCaptureDate = nil
        if existingPhoto != nil { removesExistingPhoto = true }
    }

    // MARK: Saving

    /// Writes the entry. Returns true when the sheet should dismiss.
    func save() async -> Bool {
        guard let kilograms = parsedKilograms else { return false }
        isSaving = true
        defer { isSaving = false }

        // Bytes first, then the row. An interrupted save can leave an
        // unreferenced file (harmless, swept up at launch) but never a row
        // pointing at an image that does not exist.
        var storedPhoto: StoredPhoto?
        if let pendingImage {
            do {
                storedPhoto = try await photoStore.store(
                    pendingImage,
                    capturedAt: pendingImageCaptureDate,
                    pose: .front
                )
            } catch {
                AppLog.photos.error("Photo store failed: \(String(describing: error))")
                errorMessage = "That photo could not be saved, so the entry was not saved either. Please try again."
                return false
            }
        }

        let draft = WeightEntryDraft(
            measuredAt: measuredAt,
            weightKilograms: kilograms,
            note: note,
            photo: storedPhoto,
            removesExistingPhoto: removesExistingPhoto,
            source: mode.existingEntry?.source ?? .manual
        )

        let succeeded: Bool
        if let existing = mode.existingEntry {
            succeeded = await journey.updateEntry(id: existing.id, with: draft)
        } else {
            succeeded = await journey.createEntry(draft)
        }

        if !succeeded, let identifier = storedPhoto?.assetIdentifier {
            await photoStore.remove(assetIdentifier: identifier)
        }
        return succeeded
    }

    func delete() async {
        guard let existing = mode.existingEntry else { return }
        await journey.deleteEntry(id: existing.id)
    }
}
