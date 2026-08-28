import SwiftUI
import UIKit

/// Bridges `UIImagePickerController` in camera mode into SwiftUI.
///
/// SwiftUI has no native camera capture as of iOS 17, and `UIImagePickerController`
/// gives the standard system capture UI for free — including the permission
/// prompt, flash and camera switching — which is the right level of investment
/// for Phase 1. A custom `AVCaptureSession` becomes worthwhile only when the
/// ghost-overlay alignment feature lands.
struct CameraPicker: UIViewControllerRepresentable {
    /// Called with the captured image, or `nil` if the user cancelled.
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraDevice = .front
        controller.allowsEditing = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }

    /// False in the Simulator and on devices with no usable camera, so the UI
    /// can hide the button rather than presenting a black screen.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
