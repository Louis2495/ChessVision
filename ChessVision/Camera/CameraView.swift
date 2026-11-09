import SwiftUI
import UIKit
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    var onPhoto: (UIImage) -> Void
    var onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera
        picker.cameraCaptureMode = .photo; picker.delegate = context.coordinator
        let label = UILabel(frame: CGRect(x:20,y:80,width:UIScreen.main.bounds.width-40,height:90))
        label.text = "Hold directly above the board.\nInclude all four corners and a small margin.\nWhite's home rank should be nearest you."
        label.numberOfLines = 3; label.textAlignment = .center; label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6); label.layer.cornerRadius = 12; label.clipsToBounds = true
        let overlay = UIView(frame: UIScreen.main.bounds); overlay.isUserInteractionEnabled = false; overlay.addSubview(label); picker.cameraOverlayView = overlay
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey:Any]) {
            guard let original = info[.originalImage] as? UIImage else { parent.onCancel(); return }
            // Normalize EXIF orientation once and cap memory before Vision processing.
            let scale = min(1,2048/max(original.size.width, original.size.height))
            let size = CGSize(width: original.size.width*scale, height:original.size.height*scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let normalized = UIGraphicsImageRenderer(size:size,format:format).image { _ in original.draw(in:CGRect(origin:.zero,size:size)) }
            parent.onPhoto(normalized)
        }
    }
}
