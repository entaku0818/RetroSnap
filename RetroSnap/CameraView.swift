

import SwiftUI
import UIKit
import AVFoundation

import UIKit
import AVFoundation

class CameraViewController: UIViewController {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var cameraOutput: AVCapturePhotoOutput!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        captureSession = AVCaptureSession()

        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            print("Unable to access the camera!")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            // Photo output
            cameraOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(cameraOutput) {
                captureSession.addOutput(cameraOutput)
            }

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            captureSession.startRunning()

        } catch {
            print("Error accessing the camera: \(error)")
        }

        // Add a capture button
        let captureButton = UIButton(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.center = CGPoint(x: view.center.x, y: view.bounds.maxY - 100)
        captureButton.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
        view.addSubview(captureButton)
    }

    @objc func takePhoto() {
        let settings = AVCapturePhotoSettings()
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }

    //... Other UIViewController methods ...
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data)?.sepiaTone() else {
            return
        }

        // Do something with the image (e.g., save to photo library, etc.)
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}



struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // 何もすることはありません
    }
}
