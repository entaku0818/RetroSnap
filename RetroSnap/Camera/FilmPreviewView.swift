//
//  FilmPreviewView.swift
//  RetroSnap
//
//  ライブプレビュー。**生の映像ではなく現像済みの映像を出す。**
//
//  ★設計の要点: 現像は FilmRenderer.develop に一本化してある。
//   プレビューと撮影後の1枚が同じステージ列を通るので、「選んだ瞬間に見えた写り」と
//   「保存された写り」がずれない。ここに画像処理を書き足してはいけない。
//

import CoreImage
import UIKit

final class FilmPreviewView: UIView {

    // MARK: - 依存

    private let renderer: FilmRenderer

    /// 現像はメインスレッドから逃がす。プレビューは1フレームごとにここを通る。
    private let renderQueue = DispatchQueue(label: "com.entaku.RetroSnap.FilmPreview", qos: .userInitiated)

    /// `_camera` と `isRendering` を守る。どちらもメインと renderQueue の両方から触る。
    private let lock = NSLock()

    // MARK: - 状態

    private var _camera: CameraSpec

    /// 表示に使うカメラ。
    ///
    /// 差し替えた瞬間に**直近のフレームを現像し直す**。次のフレームが来るのを待たないので、
    /// カルーセルで選んだ手応えがそのコマで返る（暗所で fps が落ちていても同じ）。
    var camera: CameraSpec {
        get { lock.withLock { _camera } }
        set {
            lock.withLock { _camera = newValue }
            renderQueue.async { [weak self] in self?.renderLatestFrame() }
        }
    }

    /// 現像が追いつかない間に届いたフレームは捨てる。
    private var isRendering = false

    /// renderQueue の上でだけ触る。
    private var latestFrame: CIImage?
    private var targetPixelWidth: CGFloat = 0

    // MARK: - 初期化

    init(camera: CameraSpec, renderer: FilmRenderer = .shared) {
        self._camera = camera
        self.renderer = renderer
        super.init(frame: .zero)

        backgroundColor = .black
        layer.contentsGravity = .resizeAspectFill
        layer.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // 現像コストは画素数に比例する。表示に必要な解像度より上は無駄なので落としてから現像する。
        // CameraSpec の各パラメータは画像サイズに対する比率で定義されているため、
        // 縮小しても効果の見え方は変わらない（＝撮影後の1枚と同じ絵になる）。
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let width = bounds.width * scale
        renderQueue.async { [weak self] in self?.targetPixelWidth = width }
    }

    // MARK: - フレームの投入

    /// 1フレーム分の映像を現像して表示する。カメラの映像出力キューから呼ぶ。
    func enqueue(_ frame: CIImage) {
        lock.lock()
        if isRendering {
            lock.unlock()
            return
        }
        isRendering = true
        lock.unlock()

        renderQueue.async { [weak self] in
            guard let self else { return }
            self.latestFrame = frame
            self.renderLatestFrame()
            self.lock.withLock { self.isRendering = false }
        }
    }

    // MARK: - 現像

    private func renderLatestFrame() {
        guard let frame = latestFrame else { return }

        let source = downscaled(frame)
        let spec = camera
        guard let developed = renderer.develop(source, with: spec),
              let rendered = renderer.rasterize(developed) else { return }

        DispatchQueue.main.async { [weak self] in self?.show(rendered) }
    }

    private func downscaled(_ frame: CIImage) -> CIImage {
        let width = frame.extent.width
        guard targetPixelWidth > 0, width > targetPixelWidth else { return frame }

        let ratio = targetPixelWidth / width
        return frame.transformed(by: CGAffineTransform(scaleX: ratio, y: ratio))
    }

    private func show(_ image: CGImage) {
        // 暗黙アニメーションが入るとフレームごとにクロスフェードして残像に見える。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = image
        CATransaction.commit()
    }
}
