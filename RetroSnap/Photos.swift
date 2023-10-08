import Foundation
import ComposableArchitecture
@preconcurrency import SwiftUI

struct Photos: Reducer {
    struct Photo: Identifiable, Equatable {
        var id: UUID
        var name: String
        var imageURL: URL
    }

    struct State: Equatable {
        var photos: IdentifiedArrayOf<Photo> = []

        var filteredPhotos: IdentifiedArrayOf<Photo> {
            return self.photos  // 今回はフィルタリングのロジックを省略しています
        }
    }

    enum Action: BindableAction, Equatable, Sendable {
        case addPhotoButtonTapped
        case binding(BindingAction<State>)
        case delete(IndexSet)
        case photoTapped(id: Photo.ID)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .addPhotoButtonTapped:
                let newPhoto = Photo(id: UUID(), name: "New Photo", imageURL: URL(string: "https://example.com/new_photo")!)
                state.photos.insert(newPhoto, at: 0)
                return .none

            case .binding:
                return .none

            case let .delete(indexSet):
                state.photos.remove(atOffsets: indexSet)
                return .none

            case .photoTapped(let id):
                // ここで写真をタップしたときの処理を追加できます
                return .none
            }
        }
    }
}

struct PhotosView: View {
    let store: StoreOf<Photos>

    init(store: StoreOf<Photos>) {
        self.store = store
    }

    // 3つの列のレイアウトを定義
    private var columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewStore.photos) { photo in
                            PhotoRowView(photo: photo)
                                .onTapGesture {
                                    NavigationLink(destination: PhotoDetailView(photo: photo)) {
                                        PhotoRowView(photo: photo)
                                    }
                                }
                        }
                    }
                    .padding() // グリッドのパディングを調整
                }
                .navigationTitle("Photos")
                .navigationBarItems(
                    trailing: Button("Add Photo") {
                        viewStore.send(.addPhotoButtonTapped)
                    }
                )
            }
        }
    }
}

struct PhotoRowView: View {
    let photo: Photos.Photo

    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: photo.imageURL) { image in
                image.resizable()
                     .aspectRatio(contentMode: .fill)
            } placeholder: {
                // ここには、画像がロードされるまでのプレースホルダを配置できます
                ProgressView()
            }.frame(width: 100, height: 100)
            .clipped()
        }
        .onTapGesture {
            // ここで写真をタップしたときの処理を追加できます
        }

    }
}

extension Photos.Photo {
    static let mock: [Self] = [
        Photos.Photo(id: UUID(), name: "Sample Photo 1", imageURL: URL(string: "https://pbs.twimg.com/profile_images/1598892937131458560/sgidJlol_400x400.jpg")!),
        Photos.Photo(id: UUID(), name: "Sample Photo 1", imageURL: URL(string: "https://pbs.twimg.com/profile_images/1598892937131458560/sgidJlol_400x400.jpg")!),
        Photos.Photo(id: UUID(), name: "Sample Photo 1", imageURL: URL(string: "https://pbs.twimg.com/profile_images/1598892937131458560/sgidJlol_400x400.jpg")!),
        Photos.Photo(id: UUID(), name: "Sample Photo 1", imageURL: URL(string: "https://pbs.twimg.com/profile_images/1598892937131458560/sgidJlol_400x400.jpg")!),
        Photos.Photo(id: UUID(), name: "Sample Photo 1", imageURL: URL(string: "https://pbs.twimg.com/profile_images/1598892937131458560/sgidJlol_400x400.jpg")!),
        Photos.Photo(id: UUID(), name: "Sample Photo 1", imageURL: URL(string: "https://pbs.twimg.com/profile_images/1598892937131458560/sgidJlol_400x400.jpg")!),
        Photos.Photo(id: UUID(), name: "Sample Photo 1", imageURL: URL(string: "https://pbs.twimg.com/profile_images/1598892937131458560/sgidJlol_400x400.jpg")!),
        Photos.Photo(id: UUID(), name: "Sample Photo 2", imageURL: URL(string: "https://pbs.twimg.com/profile_images/1598892937131458560/sgidJlol_400x400.jpg")!)
    ]
}

struct PhotosView_Previews: PreviewProvider {
    static var previews: some View {
        PhotosView(
            store: Store(initialState: Photos.State(photos: IdentifiedArrayOf(uniqueElements: Photos.Photo.mock))) {
                Photos()
            }
        )
    }
}
