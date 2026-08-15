//
//  SettingsView.swift
//  RetroSnap
//
//  撮影画面の歯車から開く設定。
//
//  ★ここに「購入を復元」を置くことは要件（App Review Guideline 3.1.1）。
//   購入導線（カメラストア）と並べて、購入まわりの入口をこの1画面に集約する。
//

import SwiftUI

struct SettingsView: View {

    @ObservedObject var store: StoreClient

    @Environment(\.dismiss) private var dismiss

    @State private var isShowingStore = false
    @State private var isRestoring = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button {
                        isShowingStore = true
                    } label: {
                        HStack {
                            Label("settings.cameraStore", systemImage: "camera.aperture")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.cameraStore")

                    Button {
                        Task { await restore() }
                    } label: {
                        HStack {
                            Label("store.restore", systemImage: "arrow.clockwise")
                            Spacer()
                            if isRestoring { ProgressView() }
                        }
                    }
                    .disabled(isRestoring)
                    .accessibilityIdentifier("settings.restore")
                } footer: {
                    Text("store.footer.restore")
                }

                Section {
                    // 何を持っているかが分かるようにしておく。復元が効いたかの確認にもなる。
                    ForEach(CameraCatalog.all) { spec in
                        HStack {
                            Text(LocalizedStringKey(spec.displayNameKey))
                            Spacer()
                            Text(ownershipLabel(for: spec))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("settings.cameras")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("store.close") { dismiss() }
                        .accessibilityIdentifier("store.close")
                }
            }
            .sheet(isPresented: $isShowingStore) {
                CameraStoreView(store: store)
            }
        }
        .task { await store.refresh() }
    }

    private func ownershipLabel(for spec: CameraSpec) -> LocalizedStringKey {
        guard spec.isPurchasable else { return "store.free" }
        return store.isUnlocked(spec) ? "store.owned" : "store.locked"
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        switch await store.restore() {
        case .restored(let count):
            message = String(localized: "store.message.restored \(count)")
        case .nothingToRestore:
            message = String(localized: "store.message.nothingToRestore")
        case .failed(let reason):
            message = reason
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: StoreClient(startsListening: false))
    }
}
