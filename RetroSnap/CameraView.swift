

import SwiftUI
import UIKit
import AVFoundation
import Photos
import ComposableArchitecture
import AppTrackingTransparency


class CameraViewController: UIViewController {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var cameraOutput: AVCapturePhotoOutput!
    var capturedImageView: UIImageView!
    var closeButton: UIButton!
    var goToPhotosButton: UIButton!
    var captureButton: UIButton!


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
        setupGoToPhotosButton()

        checkTrackingAuthorizationStatus()
    }

    private func checkTrackingAuthorizationStatus() {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined:
            requestTrackingAuthorization()
        case .restricted:  break
        case .denied:  break
        case .authorized:  break
        @unknown default:  break
        }
    }

    private func requestTrackingAuthorization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .notDetermined: break
                case .restricted:  break
                case .denied:  break
                case .authorized:  break
                @unknown default:  break
                }
            }
        }
    }

    func setupGoToPhotosButton() {
        goToPhotosButton = UIButton(frame: CGRect(x: view.bounds.width - 60, y: view.bounds.height - 140, width: 45, height: 45))
        goToPhotosButton.backgroundColor = .white
        goToPhotosButton.tintColor = .black
        goToPhotosButton.layer.cornerRadius = 5
        if let photoImage = UIImage(systemName: "photo") { // This is just one of many symbols available
            goToPhotosButton.setImage(photoImage, for: .normal)
        }
        goToPhotosButton.addTarget(self, action: #selector(openPhotosView), for: .touchUpInside)
        view.addSubview(goToPhotosButton)
    }

    @objc func openPhotosView() {
        let photosView = PhotosView(store: Store(initialState: Photos.State()) {
            Photos()
        })
        let hostVC = UIHostingController(rootView: photosView)
        self.present(hostVC, animated: true)
    }

    @objc func hideCapturedImage() {
        capturedImageView.isHidden = true
        captureButton.isHidden = false
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
        captureButton = UIButton(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.center = CGPoint(x: view.center.x, y: view.bounds.maxY - 120)
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
            if let data = image.sepiaTone()?.pngData() {
                try data.write(to: fileURL)
                return fileURL
            }
        } catch {
            print("Failed to save image to file system: \(error)")
        }

        return nil
    }


    // 「写真」アプリへ保存する。
    // 読み取りは一切しないので .addOnly で要求する（要求する権限を最小にする）
    func saveImageToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                // 断られてもアプリ内には保存済みなので、撮影自体は成立させる
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { _, error in
                if let error {
                    print("Failed to save image to photo library: \(error)")
                }
            }
        }
    }

}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data),let path = saveImageToFileSystem(image: image) else {
            return
        }

        let displayImage = image.sepiaTone()?.orientedImage(for: UIDevice.current.orientation)

        capturedImageView.image = displayImage
        capturedImageView.isHidden = false
        captureButton.isHidden = true

        closeButton.isHidden = false
        previewLayer.isHidden = true

        PhotoRepository.shared.insert(name: "", path: path)

        // 画面に出したものと同じ絵をアルバムへ入れる
        if let displayImage {
            saveImageToPhotoLibrary(displayImage)
        }

        showSavedMessage()
    }

    func showSavedMessage() {
        let alert = UIAlertController(title: nil, message: String(localized: "Save Photo"), preferredStyle: .alert)
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


struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
