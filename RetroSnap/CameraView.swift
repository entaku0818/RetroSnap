

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
    var settingsButton: UIButton!
    /// カメラ切替カルーセル（SwiftUI）のホスト。
    private var carouselHost: UIHostingController<CameraCarouselView>!
    /// 未購入カメラで撮ったときに出す「保存には購入が要る」の掲示。
    private var lockedNoticeView: UIView!

    /// 撮影画面とカルーセルが共有する選択状態。ラインナップは CameraCatalog が唯一の情報源。
    let cameraSelection = CameraSelection()
    private var selectionObservation: AnyCancellable?

    /// 所有判定の唯一の入口。
    let store = StoreClient.shared

    /// 現像は済んだが、未購入カメラだったので保存を保留している1枚。
    /// 購入が通ったらこれを保存する。買わずに閉じたら保存しないまま捨てる。
    private var pendingCapture: (image: UIImage, camera: CameraSpec)?

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
        setupSettingsButton()
        setupCameraCarousel()
        setupLockedNotice()

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

    /// 設定（購入の復元・カメラストアへの導線）を開く歯車。
    func setupSettingsButton() {
        settingsButton = UIButton(frame: CGRect(x: 15, y: 20, width: 45, height: 45))
        if let gear = UIImage(systemName: "gearshape") {
            settingsButton.setImage(gear, for: .normal)
            settingsButton.tintColor = .white
        }
        settingsButton.accessibilityIdentifier = "camera.settings"
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)
    }

    @objc func openSettings() {
        let settings = SettingsView(store: store)
        present(UIHostingController(rootView: settings), animated: true)
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
        lockedNoticeView.isHidden = true
        settingsButton.isHidden = false
        // 買わずに閉じたので、この1枚は保存しないまま捨てる。
        pendingCapture = nil
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
        let carousel = CameraCarouselView(selection: cameraSelection, store: store)
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

    // MARK: - 購入ゲート

    /// 未購入カメラで撮ったときに、撮った絵の上に出す掲示。
    ///
    /// 「押しても何も起きない」を作らないための面。写りは見せたうえで、
    /// 保存できていないことと、どうすれば保存できるかを必ず文字で出す。
    private func setupLockedNotice() {
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        container.layer.cornerRadius = 14
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        container.accessibilityIdentifier = "camera.lockedNotice"

        let label = UILabel()
        label.text = String(localized: "capture.locked.notice")
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle(String(localized: "capture.locked.openStore"), for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 10
        button.accessibilityIdentifier = "camera.lockedNotice.openStore"
        button.addTarget(self, action: #selector(openStoreForPendingCapture), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(button)
        view.addSubview(container)
        lockedNoticeView = container

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),

            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            button.heightAnchor.constraint(equalToConstant: 44),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
    }

    @objc private func openStoreForPendingCapture() {
        presentCameraStore(highlighting: pendingCapture?.camera.id)
    }

    /// カメラストアを出す。閉じたときに所有状態を見直し、買えていれば保留中の1枚を保存する。
    private func presentCameraStore(highlighting id: CameraID?) {
        let storeView = CameraStoreView(
            store: store,
            highlighted: id,
            onFinish: { [weak self] in self?.savePendingCaptureIfUnlocked() }
        )
        present(UIHostingController(rootView: storeView), animated: true)
    }

    /// 購入が通っていれば、保留していた1枚をそのまま保存する。
    /// 通っていなければ掲示を出したまま何もしない（黙って消さない）。
    private func savePendingCaptureIfUnlocked() {
        guard let pending = pendingCapture, store.isUnlocked(pending.camera) else { return }

        pendingCapture = nil
        lockedNoticeView.isHidden = true
        save(pending.image, camera: pending.camera)
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
        captureButton.accessibilityIdentifier = "camera.shutter"
        captureButton.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
        view.addSubview(captureButton)
    }

    @objc func takePhoto() {
        if let cameraOutput {
            let settings = AVCapturePhotoSettings()
            cameraOutput.capturePhoto(with: settings, delegate: self)
            return
        }

        // 実カメラが無いのはシミュレータだけ。プレビューと同じ1枚をシャッターの結果として流し、
        // 購入ゲートから保存までを実機と同じ経路で確認できるようにする。
        #if targetEnvironment(simulator)
        if let still = SamplePreviewFrame.makeImage() {
            handleCapturedImage(still)
        }
        #endif
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
        handleCapturedImage(image)
    }
}

extension CameraViewController {

    /// 撮れた1枚を現像し、購入ゲートを通してから保存する。撮影経路はここに集約する。
    func handleCapturedImage(_ image: UIImage) {
        // シャッターを切った時点の選択で現像する。
        // 現像中にカルーセルを触られても、出てくる絵はプレビューで見えていたものと一致する。
        let camera = selectedCamera

        // 現像は多段フィルタになったのでメインスレッドから逃がす。
        // 保存・表示・アルバムのすべてが、この1枚の現像結果を共有する
        FilmRenderer.shared.render(image, with: camera) { [weak self] developed in
            guard let self, let developed else { return }

            // 現像結果は購入の有無にかかわらず必ず見せる。
            // ゲートを掛けるのは保存だけ（写りを隠したら単品売りにならない）。
            self.showCaptured(developed)

            switch CaptureGate.disposition(for: camera, entitlements: self.store) {
            case .save:
                self.save(developed, camera: camera)

            case .requirePurchase(let id):
                // 保存はしない。1枚を抱えたまま購入を求める。
                self.pendingCapture = (developed, camera)
                self.lockedNoticeView.isHidden = false
                self.presentCameraStore(highlighting: id)
            }
        }
    }

    /// 撮った1枚を確認用に表示する。
    private func showCaptured(_ image: UIImage) {
        capturedImageView.image = image
        capturedImageView.isHidden = false
        captureButton.isHidden = true
        carouselHost.view.isHidden = true
        settingsButton.isHidden = true

        closeButton.isHidden = false
        filmPreviewView.isHidden = true
    }

    /// アプリ内・CoreData・アルバムへ保存する。ここへ来るのは購入済み（または無料）のときだけ。
    private func save(_ image: UIImage, camera: CameraSpec) {
        guard let path = saveImageToFileSystem(image: image) else { return }

        // どのカメラで撮ったかを写真ごとに残す（写真一覧でカメラ別に扱えるようにするため）
        PhotoRepository.shared.insert(name: "", path: path, cameraID: camera.id)

        // 画面に出したものと同じ絵をアルバムへ入れる
        saveImageToPhotoLibrary(image)

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
