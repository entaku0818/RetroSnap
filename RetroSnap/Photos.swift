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

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationStack {
                List {
                     ForEach(viewStore.photos) { photo in
                         PhotoRowView(photo: photo)
                             .onTapGesture {
                                 viewStore.send(.photoTapped(id: photo.id))
                             }
                     }
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
            Text(photo.name)
            AsyncImage(url: photo.imageURL)
        }
        .onTapGesture {
            // ここで写真をタップしたときの処理を追加できます
        }

    }
}

extension Photos.Photo {
    static let mock: [Self] = [
        Photos.Photo(id: UUID(), name: "Sample Photo 1", imageURL: URL(string: "https://example.com/photo1")!),
        Photos.Photo(id: UUID(), name: "Sample Photo 2", imageURL: URL(string: "https://example.com/photo2")!)
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
