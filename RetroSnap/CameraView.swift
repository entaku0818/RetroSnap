

import SwiftUI
import UIKit
import AVFoundation
import Photos


class CameraViewController: UIViewController {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var cameraOutput: AVCapturePhotoOutput!
    var capturedImageView: UIImageView!
    var closeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCameraSession()

        // 画像を表示するUIImageViewを作成
        capturedImageView = UIImageView(frame: view.bounds)
        capturedImageView.contentMode = .scaleToFill
        capturedImageView.isHidden = true
        view.addSubview(capturedImageView)

        // 閉じるボタンを追加
        closeButton = UIButton(frame: CGRect(x: view.bounds.width - 50, y: 20, width: 45, height: 45))
        if let closeImage = UIImage(systemName: "xmark") {
            closeButton.setImage(closeImage, for: .normal)
            closeButton.tintColor = .white
        }
        closeButton.addTarget(self, action: #selector(hideCapturedImage), for: .touchUpInside)
        closeButton.isHidden = true
        view.addSubview(closeButton)

        setupCaptureButton()
    }

    @objc func hideCapturedImage() {
        capturedImageView.isHidden = true
        closeButton.isHidden = true
        previewLayer.isHidden = false
    }

    func setupCameraSession() {
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
    }

    func setupCaptureButton() {
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

    // FileSystem上に保存する
    func saveImageToFileSystem(image: UIImage) -> URL? {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = UUID().uuidString + ".png"
        let fileURL = directory.appendingPathComponent(fileName)

        do {
            if let data = image.pngData() {
                try data.write(to: fileURL)
                return fileURL
            }
        } catch {
            print("Failed to save image to file system: \(error)")
        }

        return nil
    }


    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            // you have permission, you can proceed
            break
        case .denied, .restricted:
            // you don't have permission
            break
        case .notDetermined:
            // you didn't ask for permission yet, ask for it
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized:
                    // user granted permission
                    break
                default:
                    // user denied permission
                    break
                }
            }
        case .limited:
            break
        @unknown default:
            break
        }
    }

}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data),let path = saveImageToFileSystem(image: image) else {
            return
        }

        capturedImageView.image = image.sepiaTone()?.orientedImage(for: UIDevice.current.orientation)
        capturedImageView.isHidden = false

        closeButton.isHidden = false
        previewLayer.isHidden = true
        checkPhotoLibraryPermission()
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        PhotoRepository.shared.insert(name: "", path: path)

        showSavedMessage()
    }

    func showSavedMessage() {
        let alert = UIAlertController(title: nil, message: "保存されました", preferredStyle: .alert)
        present(alert, animated: true, completion: nil)

        // 2秒後にアラートを自動的に閉じる
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            alert.dismiss(animated: true, completion: nil)
        }
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


