//
//  ContentView.swift
//  RetroSnap
//
//  Created by 遠藤拓弥 on 30.9.2023.
//

import SwiftUI



struct ContentView: View {
    @State private var selectedImage: Image? = nil
    @State private var showingImagePicker = false

    var body: some View {
        VStack {
            selectedImage?
                .resizable()
                .scaledToFit()
                .padding()

            Button("Select Photo") {
                showingImagePicker = true
            }
        }
        .padding()
        .sheet(isPresented: $showingImagePicker, content: {
            ImagePicker(image: $selectedImage)
        })
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: Image?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> some UIViewController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage,let retroImage = applyRetroEffect(to: uiImage) {
                parent.image = Image(uiImage: retroImage)
            }

            picker.dismiss(animated: true, completion: nil)
        }
    }
}


func applyRetroEffect(to image: UIImage) -> UIImage? {
    let context = CIContext(options: nil)

    if let filter = CIFilter(name: "CISepiaTone") {
        filter.setValue(CIImage(image: image), forKey: kCIInputImageKey)
        filter.setValue(0.7, forKey: kCIInputIntensityKey) // インテンシティの値を調整することでセピアの深さを変えられます

        if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
    }

    return nil
}


@available(iOS 15.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
