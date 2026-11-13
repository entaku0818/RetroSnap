import SwiftUI
import PhotosUI

struct PhotoIconCreatorView: View {
    var initialPhotoURL: URL? = nil
    @StateObject private var model = PhotoIconModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showGuide = false
    @State private var showMessage = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("icon.intro")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Group {
                    if let preview = model.preview {
                        Image(uiImage: preview).resizable().scaledToFit()
                            .accessibilityLabel(Text("icon.preview"))
                    } else {
                        RoundedRectangle(cornerRadius: 36)
                            .fill(Color(white: 0.12))
                            .overlay {
                                VStack(spacing: 12) {
                                    Image(systemName: "film").font(.system(size: 64))
                                    Text("icon.empty").font(.subheadline)
                                }
                                .foregroundStyle(Color(red: 1, green: 0.96, blue: 0.85))
                            }
                    }
                }
                .frame(width: 260, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
                .overlay { if model.isLoading { ProgressView().tint(.orange) } }
                .accessibilityIdentifier("icon.preview")

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("icon.choose", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)
                .disabled(model.isSaving)
                .accessibilityIdentifier("icon.choose")

                if model.photo != nil {
                    VStack(spacing: 16) {
                        adjustment("icon.zoom", value: $model.zoom, range: 1...3)
                        adjustment("icon.horizontal", value: $model.horizontal, range: -1...1)
                        adjustment("icon.vertical", value: $model.vertical, range: -1...1)
                        Button("icon.reset") { model.reset() }
                    }
                    .disabled(model.isLoading || model.isSaving)
                }

                Button {
                    Task { await model.save() }
                } label: {
                    HStack {
                        if model.isSaving { ProgressView() }
                        Label("icon.save", systemImage: "square.and.arrow.down")
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(model.photo == nil || model.isLoading || model.isSaving)
                .accessibilityIdentifier("icon.save")

                Button {
                    showGuide = true
                } label: {
                    Label("icon.guide.title", systemImage: "house")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("icon.guide")
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("icon.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let initialPhotoURL, model.photo == nil { await model.load(url: initialPhotoURL) }
        }
        .task(id: selectedPhoto) {
            if let selectedPhoto { await model.load(item: selectedPhoto) }
        }
        .navigationDestination(isPresented: $showGuide) {
            PhotoIconGuideView()
        }
        .onChange(of: model.message) { message in
            showMessage = message != nil
        }
        .onChange(of: showMessage) { presented in
            if !presented { model.message = nil }
        }
        .alert("icon.title", isPresented: $showMessage) {
            if model.permissionDenied {
                Button("icon.openSettings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
            if model.saved {
                Button("icon.guide.title") { showGuide = true }
            }
            Button("OK", role: .cancel) { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
    }

    private func adjustment(_ key: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            Text(key).font(.subheadline)
            Slider(value: value, in: range).accessibilityLabel(Text(key))
        }
    }
}

#Preview {
    NavigationStack { PhotoIconCreatorView() }
}

private struct PhotoIconGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("icon.guide.step1")
                Text("icon.guide.step2")
                Text("icon.guide.step3")
                Text("icon.guide.step4")
                Text("icon.guide.note").font(.footnote).foregroundStyle(.secondary)
                Link("icon.guide.apple", destination: URL(string: "https://support.apple.com/guide/shortcuts/apd735880972/ios")!)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("icon.guide.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
