import Foundation
import ImageIO

/// Reads capture metadata straight out of image data.
///
/// Deliberately EXIF-based rather than PhotoKit-based: reading the bytes the
/// picker already handed us needs no photo library permission at all, which
/// matters for an app whose privacy promise is the reason people trust it with
/// these images. It is also exactly what historical photo matching will need in
/// a later phase.
enum ImageMetadata {
    /// The date the photo was taken, when the file records one.
    ///
    /// EXIF stores this without a time zone, so it is interpreted in the
    /// device's current zone — the same assumption Photos itself makes when it
    /// has nothing better.
    static func captureDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
               let date = parse(original) {
                return date
            }
            if let digitised = exif[kCGImagePropertyExifDateTimeDigitized] as? String,
               let date = parse(digitised) {
                return date
            }
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let value = tiff[kCGImagePropertyTIFFDateTime] as? String {
            return parse(value)
        }

        return nil
    }

    /// EXIF dates use `yyyy:MM:dd HH:mm:ss` with colons in the date part.
    private static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}
