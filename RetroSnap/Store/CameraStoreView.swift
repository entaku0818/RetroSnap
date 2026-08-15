//
//  CameraStoreView.swift
//  RetroSnap
//
//  カメラストア（購入導線）。
//
//  ★設計の要点:
//   - ラインナップは `CameraCatalog.all` から生成する。ここにカメラ名も価格も書かない
//     （価格は StoreKit が返す `displayPrice`。通貨・地域で変わるので直書きは事故になる）。
//   - 「購入を復元」を必ず置く（App Review Guideline 3.1.1）。
//   - 購入の結末（キャンセル / 承認待ち / 失敗 / 商品が取れない）は**必ず1行出す**。
//     押したのに何も起きない、という状態を作らない。
//

import StoreKit
import SwiftUI

struct CameraStoreView: View {

    @ObservedObject var store: StoreClient

    /// 開いたときに強調したいカメラ（保存でゲートに当たった1台）。
    var highlighted: CameraID?

    /// 閉じたときに呼ばれる。呼び出し元が所有状態を見直すために使う
    /// （買った直後に、保留していた1枚を保存する経路）。
    var onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// 直近の操作の結果。ここが nil でない限り画面に出す。
    @State private var message: String?
    @State private var isRestoring = false

    private var cameras: [CameraSpec] { CameraCatalog.all }

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
                    ForEach(cameras) { spec in
                        CameraStoreRow(
                            spec: spec,
                            product: store.products[spec.productID],
                            isOwned: store.isUnlocked(spec),
                            isPurchasing: store.purchasingProductIDs.contains(spec.productID),
                            isHighlighted: spec.id == highlighted
                        ) {
                            Task { await buy(spec) }
                        }
                    }
                } footer: {
                    Text("store.footer.preview")
                }

                Section {
                    Button {
                        Task { await restore() }
                    } label: {
                        HStack {
                            Text("store.restore")
                            Spacer()
                            if isRestoring { ProgressView() }
                        }
                    }
                    .disabled(isRestoring)
                } footer: {
                    Text("store.footer.restore")
                }
            }
            .navigationTitle("store.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("store.close") { dismiss() }
                        .accessibilityIdentifier("store.close")
                }
            }
            .overlay {
                if store.isLoadingProducts && store.products.isEmpty {
                    ProgressView()
                }
            }
        }
        .onDisappear { onFinish?() }
        .task {
            await store.refresh()
            // 商品が1つも取れないと価格も購入ボタンも出せない。理由を必ず出す。
            if let failure = store.productLoadFailure {
                message = failure
            }
        }
    }

    // MARK: - 操作

    private func buy(_ spec: CameraSpec) async {
        switch await store.purchase(spec) {
        case .purchased:
            message = String(localized: "store.message.purchased")
        case .free:
            message = String(localized: "store.message.alreadyFree")
        case .cancelled:
            message = String(localized: "store.message.cancelled")
        case .pending:
            message = String(localized: "store.message.pending")
        case .unavailable:
            message = String(localized: "store.error.productsUnavailable")
        case .failed(let reason):
            message = reason
        }
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

// MARK: - 1台分の行

private struct CameraStoreRow: View {

    let spec: CameraSpec
    let product: Product?
    let isOwned: Bool
    let isPurchasing: Bool
    let isHighlighted: Bool
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(spec.displayNameKey))
                    .font(.body.weight(isHighlighted ? .semibold : .regular))
                Text(LocalizedStringKey(spec.taglineKey))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            action
        }
        .padding(.vertical, 2)
        .listRowBackground(isHighlighted ? Color.accentColor.opacity(0.08) : nil)
        .accessibilityIdentifier("store.row.\(spec.id.rawValue)")
    }

    @ViewBuilder
    private var action: some View {
        if isOwned {
            // 無料カメラもここに入る。買えるものと区別が付くように文言を分ける。
            Text(spec.isPurchasable ? "store.owned" : "store.free")
                .font(.caption)
                .foregroundColor(.secondary)
        } else if isPurchasing {
            ProgressView()
        } else if let product {
            Button(product.displayPrice, action: onBuy)
                .font(.callout.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("store.buy.\(spec.id.rawValue)")
        } else {
            // 価格が出せない = 買えない。空欄にせず理由が分かる表示にする。
            Text("store.unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct CameraStoreView_Previews: PreviewProvider {
    static var previews: some View {
        CameraStoreView(store: StoreClient(startsListening: false), highlighted: CameraSpec.nightNeon.id)
    }
}
