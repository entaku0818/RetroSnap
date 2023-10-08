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

    var body: some View {
        VStack {
            AsyncImage(url: photo.imageURL) { image in
                image.resizable()
                     .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            Spacer()
        }
        .navigationBarTitle(photo.name, displayMode: .inline)
    }
}
