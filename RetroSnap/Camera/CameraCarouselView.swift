//
//  CameraCarouselView.swift
//  RetroSnap
//
//  撮影画面下部のカメラ切替カルーセル。
//
//  ★設計の要点: ラインナップは `CameraCatalog.all` が唯一の情報源。
//   このファイルにカメラ名・台数・並び順を書いてはいけない。表示名は
//   `CameraSpec.displayNameKey` 経由でローカライズカタログから引く。
//   カメラを1台足しても、触るのは CameraCatalog.swift と Localizable.xcstrings だけ。
//

import SwiftUI

// MARK: - 選択状態

/// 撮影画面と共有するカメラの選択状態。
///
/// UIKit 側（`CameraViewController`）とカルーセル（SwiftUI）の双方が同じ実体を見る。
/// 選択が変わると `selected` の変化がプレビューにも撮影にも同時に伝わる。
final class CameraSelection: ObservableObject {

    /// 選択できるカメラ。カタログをそのまま受け取る。
    let cameras: [CameraSpec]

    @Published var selected: CameraSpec

    init(cameras: [CameraSpec] = CameraCatalog.all, selected: CameraSpec = CameraCatalog.default) {
        self.cameras = cameras
        // カタログに無いカメラを選択状態にすると切替不能になるので、そのときは既定に落とす。
        self.selected = cameras.contains(selected) ? selected : (cameras.first ?? CameraCatalog.default)
    }
}

// MARK: - カルーセル

struct CameraCarouselView: View {

    @ObservedObject var selection: CameraSelection

    var body: some View {
        VStack(spacing: 10) {
            caption
            strip
        }
    }

    /// 選択中のカメラの説明。切替の結果が言葉でも分かるようにする。
    private var caption: some View {
        Text(LocalizedStringKey(selection.selected.taglineKey))
            .font(.footnote)
            .foregroundColor(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 24)
            .shadow(radius: 3)
            .animation(.easeInOut(duration: 0.15), value: selection.selected.id)
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(selection.cameras) { spec in
                        CameraChip(spec: spec, isSelected: spec.id == selection.selected.id) {
                            guard spec.id != selection.selected.id else { return }
                            withAnimation(.easeOut(duration: 0.18)) {
                                selection.selected = spec
                            }
                        }
                        .id(spec.id)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }
            .onAppear {
                proxy.scrollTo(selection.selected.id, anchor: .center)
            }
            .onChange(of: selection.selected.id) { id in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}

// MARK: - カメラ1台分のチップ

private struct CameraChip: View {

    /// UI テストがカルーセルの1台を指すための識別子。
    static func identifier(for spec: CameraSpec) -> String { "camera.chip.\(spec.id.rawValue)" }

    let spec: CameraSpec
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(LocalizedStringKey(spec.displayNameKey))
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .black : .white)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.16))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isSelected ? 0 : 0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        // UI テストからの指定に使う。ここも slug 由来なので、カメラ名を別途書き足す必要はない。
        .accessibilityIdentifier(Self.identifier(for: spec))
    }
}

// MARK: - Preview

struct CameraCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            CameraCarouselView(selection: CameraSelection())
        }
        .ignoresSafeArea()
    }
}
