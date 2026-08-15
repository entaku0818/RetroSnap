

import SwiftUI
import UIKit
import AVFoundation
import Photos
import Combine
import ComposableArchitecture
import AppTrackingTransparency


class CameraViewController: UIViewController {

    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var videoOutput: AVCaptureVideoDataOutput!
    /// 現像済みのライブプレビュー。生の映像は画面に出さない。
    var filmPreviewView: FilmPreviewView!
    var capturedImageView: UIImageView!
    var closeButton: UIButton!
    var goToPhotosButton: UIButton!
    var captureButton: UIButton!
    /// カメラ切替カルーセル（SwiftUI）のホスト。
    private var carouselHost: UIHostingController<CameraCarouselView>!

    /// 撮影画面とカルーセルが共有する選択状態。ラインナップは CameraCatalog が唯一の情報源。
    let cameraSelection = CameraSelection()
    private var selectionObservation: AnyCancellable?

    /// 現像に使うカメラ。
    var selectedCamera: CameraSpec { cameraSelection.selected }

    /// `startRunning` / `stopRunning` は同期的に時間が掛かるのでメインから逃がす。
    private let sessionQueue = DispatchQueue(label: "com.entaku.RetroSnap.CaptureSession")
    /// 映像フレームの受け口。
    private let videoQueue = DispatchQueue(label: "com.entaku.RetroSnap.VideoOutput", qos: .userInitiated)


    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        setupPreviewView()
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
        setupCameraCarousel()

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
        filmPreviewView.isHidden = false
        carouselHost.view.isHidden = false
    }

    // MARK: - プレビュー

    private func setupPreviewView() {
        filmPreviewView = FilmPreviewView(camera: selectedCamera)
        filmPreviewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filmPreviewView)
        NSLayoutConstraint.activate([
            filmPreviewView.topAnchor.constraint(equalTo: view.topAnchor),
            filmPreviewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            filmPreviewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filmPreviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - カメラ切替

    private func setupCameraCarousel() {
        let carousel = CameraCarouselView(selection: cameraSelection)
        carouselHost = UIHostingController(rootView: carousel)
        carouselHost.view.backgroundColor = .clear
        carouselHost.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(carouselHost)
        view.addSubview(carouselHost.view)
        carouselHost.didMove(toParent: self)

        // 撮影ボタン（画面下から 120pt の中心・半径 35）の真上に置く。
        NSLayoutConstraint.activate([
            carouselHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            carouselHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            carouselHost.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -170),
        ])

        // 選択が変わったらライブプレビューへ即座に伝える。
        // 撮影後ではなく「選んだ瞬間」に写りが変わるのが、このカルーセルの主目的。
        selectionObservation = cameraSelection.$selected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] spec in
                self?.filmPreviewView.camera = spec
            }
    }

    // MARK: - セッション

    func setupCameraSession() {
        captureSession = AVCaptureSession()

        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            print("Unable to access the camera!")
            showSampleFrameIfSimulator()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            captureSession.beginConfiguration()

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            // Photo output
            cameraOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(cameraOutput) {
                captureSession.addOutput(cameraOutput)
            }

            // Video output（ライブプレビューを現像するための素材）
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            // 現像が追いつかないフレームは捨てる。溜めるとプレビューが遅れて手応えが悪くなる。
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

            captureSession.commitConfiguration()

            applyPortraitOrientation(to: videoOutput.connection(with: .video))

            sessionQueue.async { [weak self] in
                self?.captureSession.startRunning()
            }

        } catch {
            print("Error accessing the camera: \(error)")
        }
    }

    /// 映像バッファは既定で横倒しなので、縦位置に揃えてから現像へ渡す。
    private func applyPortraitOrientation(to connection: AVCaptureConnection?) {
        guard let connection else { return }

        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    /// シミュレータには実カメラが無いので、代わりに手続き的な1枚を現像パイプラインへ流す。
    /// 実機では何もしない（`SamplePreviewFrame` 自体がシミュレータ限定でコンパイルされる）。
    private func showSampleFrameIfSimulator() {
        #if targetEnvironment(simulator)
        guard let frame = SamplePreviewFrame.make() else { return }
        // レイアウト確定後でないと縮小先の幅が決まらないので、次のループで流す。
        DispatchQueue.main.async { [weak self] in
            self?.filmPreviewView.enqueue(frame)
        }
        #endif
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
        guard let cameraOutput else { return }
        let settings = AVCapturePhotoSettings()
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let session = self?.captureSession, session.isRunning else { return }
            session.stopRunning()
        }
    }

    // FileSystem上に保存する。
    // 渡すのは現像済みの画像。ここで現像はしない（現像は FilmRenderer だけが行う）
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

// MARK: - ライブプレビュー

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        filmPreviewView.enqueue(CIImage(cvPixelBuffer: buffer))
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            return
        }

        // シャッターを切った時点の選択で現像する。
        // 現像中にカルーセルを触られても、出てくる絵はプレビューで見えていたものと一致する。
        let camera = selectedCamera

        // 現像は多段フィルタになったのでメインスレッドから逃がす。
        // 保存・表示・アルバムのすべてが、この1枚の現像結果を共有する
        FilmRenderer.shared.render(image, with: camera) { [weak self] developed in
            guard let self, let developed, let path = self.saveImageToFileSystem(image: developed) else {
                return
            }

            self.capturedImageView.image = developed
            self.capturedImageView.isHidden = false
            self.captureButton.isHidden = true
            self.carouselHost.view.isHidden = true

            self.closeButton.isHidden = false
            self.filmPreviewView.isHidden = true

            // どのカメラで撮ったかを写真ごとに残す（写真一覧でカメラ別に扱えるようにするため）
            PhotoRepository.shared.insert(name: "", path: path, cameraID: camera.id)

            // 画面に出したものと同じ絵をアルバムへ入れる
            self.saveImageToPhotoLibrary(developed)

            self.showSavedMessage()
        }
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
