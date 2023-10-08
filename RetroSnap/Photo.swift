//
//  Photo.swift
//  RetroSnap
//
//  Created by 遠藤拓弥 on 8.10.2023.
//

import Foundation
import SwiftUI

struct PhotoDetailView: View {
    let photo: Photos.Photo
    @State private var showShareSheet = false

    var body: some View {
        VStack {
            if let imagePath = imagePathInDocuments(fileName: photo.imageURL.lastPathComponent),
               let uiImage = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .rotationEffect(.degrees(shouldRotateImage(uiImage) ? 90 : 0))
                    .scaledToFill()
                    .frame(width: .infinity, height: .infinity)
                    .clipped()

            } else {
                ProgressView()
            }
            Spacer()
        }
        .navigationBarTitle(photo.name, displayMode: .inline)
        .navigationBarItems(trailing:
            Button(action: {
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up") // システムアイコンを使用
            }
        )
        .sheet(isPresented: $showShareSheet) {
            if let uiImage = getImage(from: self.imagePathInDocuments(fileName: photo.imageURL.lastPathComponent) ?? "") {
                ActivityView(activityItems: [uiImage])
            }
        }
    }

    func getImage(from path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
    }

    func imagePathInDocuments(fileName: String) -> String? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentDirectory = paths.first else {
            return nil
        }
        return documentDirectory.appendingPathComponent(fileName).path
    }

    func shouldRotateImage(_ image: UIImage) -> Bool {
        return image.size.width > image.size.height
    }
}


struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {
    }
}
