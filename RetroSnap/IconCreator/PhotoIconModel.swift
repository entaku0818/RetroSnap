import SwiftUI
import Photos
import PhotosUI

@MainActor
final class PhotoIconModel: ObservableObject {
    @Published private(set) var photo: UIImage?
    @Published private(set) var preview: UIImage?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var zoom: Double = 1 { didSet { updatePreview() } }
    @Published var horizontal: Double = 0 { didSet { updatePreview() } }
    @Published var vertical: Double = 0 { didSet { updatePreview() } }
    @Published var message: String?
    @Published var permissionDenied = false
    @Published var saved = false

    private var loadID = UUID()

    func load(item: PhotosPickerItem) async {
        await loadData { try await item.loadTransferable(type: Data.self) }
    }

    func load(url: URL) async {
        await loadData { try await Task.detached { try Data(contentsOf: url) }.value }
    }

    private func loadData(_ fetch: () async throws -> Data?) async {
        let id = UUID()
        loadID = id
        isLoading = true
        defer { if loadID == id { isLoading = false } }
        do {
            guard let data = try await fetch() else { throw CocoaError(.fileReadCorruptFile) }
            let image = await Task.detached { PhotoIconRenderer.decode(data) }.value
            guard !Task.isCancelled, loadID == id else { return }
            guard let image else { throw CocoaError(.fileReadCorruptFile) }
            photo = image
            reset()
            saved = false
        } catch {
            guard !Task.isCancelled, loadID == id else { return }
            message = String(localized: "icon.error.load")
        }
    }

    func reset() {
        zoom = 1
        horizontal = 0
        vertical = 0
        updatePreview()
    }

    private func updatePreview() {
        guard let photo else { return }
        saved = false
        preview = PhotoIconRenderer.render(photo, zoom: zoom,
            position: CGPoint(x: horizontal, y: vertical), pixels: 360)
    }

    func save() async {
        guard let photo, !isSaving, !isLoading else { return }
        isSaving = true
        defer { isSaving = false }
        permissionDenied = false
        let image = PhotoIconRenderer.render(photo, zoom: zoom,
            position: CGPoint(x: horizontal, y: vertical))
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            permissionDenied = true
            message = String(localized: "icon.error.permission")
            return
        }
        guard let data = image.pngData() else {
            message = String(localized: "icon.error.save")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = "RetroSnap-Icon.png"
                request.addResource(with: .photo, data: data, options: options)
            }
            saved = true
            message = String(localized: "icon.saved.message")
        } catch {
            message = String(localized: "icon.error.save")
        }
    }
}
