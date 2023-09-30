//
//  Image+extention.swift
//  RetroSnap
//
//  Created by 遠藤拓弥 on 30.9.2023.
//

import Foundation
import UIKit
import CoreImage

extension UIImage {
    func sepiaTone(intensity: Float = 0.8) -> UIImage? {
        let context = CIContext()

        if let filter = CIFilter(name: "CISepiaTone") {
            filter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
            filter.setValue(intensity, forKey: kCIInputIntensityKey)

            if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}
