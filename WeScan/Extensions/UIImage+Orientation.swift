//
//  UIImage+Orientation.swift
//  WeScan
//
//  Created by Boris Emorine on 2/16/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    
    /// Data structure to easily express rotation options.
    struct RotationOptions: OptionSet {
        let rawValue: Int
        
        static let flipOnVerticalAxis = RotationOptions(rawValue: 1)
        static let flipOnHorizontalAxis = RotationOptions(rawValue: 2)
    }
	
	var fixedOrientation: UIImage {
		guard imageOrientation != .up else { return self }
		
		var transform: CGAffineTransform = .identity
		switch imageOrientation {
		case .down, .downMirrored:
			transform = transform
				.translatedBy(x: size.width, y: size.height).rotated(by: .pi)
		case .left, .leftMirrored:
			transform = transform
				.translatedBy(x: size.width, y: 0).rotated(by: .pi)
		case .right, .rightMirrored:
			transform = transform
				.translatedBy(x: 0, y: size.height).rotated(by: -.pi/2)
		case .upMirrored:
			transform = transform
				.translatedBy(x: size.width, y: 0).scaledBy(x: -1, y: 1)
		default:
			break
		}
		
		guard
			let cgImage = cgImage,
			let colorSpace = cgImage.colorSpace,
			let context = CGContext(
				data: nil, width: Int(size.width), height: Int(size.height),
				bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0,
				space: colorSpace, bitmapInfo: cgImage.bitmapInfo.rawValue
			)
		else { return self }
		context.concatenate(transform)
		
		var rect: CGRect
		switch imageOrientation {
		case .left, .leftMirrored, .right, .rightMirrored:
			rect = CGRect(x: 0, y: 0, width: size.height, height: size.width)
		default:
			rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
		}
		
		context.draw(cgImage, in: rect)
		return context.makeImage().map { UIImage(cgImage: $0) } ?? self
	}
    
//    /// Returns the same image with a portrait orientation.
//    func applyingPortraitOrientation() -> UIImage {
//        switch imageOrientation {
//        case .up:
//            return rotated(by: Measurement(value: Double.pi, unit: .radians), options: []) ?? self
//        case .down:
//            return rotated(by: Measurement(value: Double.pi, unit: .radians), options: [.flipOnVerticalAxis, .flipOnHorizontalAxis]) ?? self
//        case .left:
//            return self
//        case .right:
//            return rotated(by: Measurement(value: Double.pi / 2.0, unit: .radians), options: []) ?? self
//        default:
//            return self
//        }
//    }
	
	func rotate(degress: CGFloat) -> UIImage? {
		let degreesToRadians: (CGFloat) -> CGFloat = {
			return $0 / 180.0 * CGFloat.pi
		}
		
		let radians = degreesToRadians(degress)
		var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: radians)).size
		// Trim off the extremely small float value to prevent core graphics from rounding it up
		newSize.width = floor(newSize.width)
		newSize.height = floor(newSize.height)
		
		UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
		let context = UIGraphicsGetCurrentContext()!
		
		// Move origin to middle
		context.translateBy(x: newSize.width/2, y: newSize.height/2)
		// Rotate around middle
		context.rotate(by: CGFloat(radians))
		// Draw the image at its center
		self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
		
		let newImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		
		return newImage
	}

//    /// Rotate the image by the given angle, and perform other transformations based on the passed in options.
//    ///
//    /// - Parameters:
//    ///   - rotationAngle: The angle to rotate the image by.
//    ///   - options: Options to apply to the image.
//    /// - Returns: The new image rotated and optentially flipped (@see options).
//    func rotated(by rotationAngle: Measurement<UnitAngle>, options: RotationOptions = []) -> UIImage? {
//        guard let cgImage = self.cgImage else { return nil }
//
//        let rotationInRadians = CGFloat(rotationAngle.converted(to: .radians).value)
//        let transform = CGAffineTransform(rotationAngle: rotationInRadians)
//        let cgImageSize = CGSize(width: cgImage.width, height: cgImage.height)
//        var rect = CGRect(origin: .zero, size: cgImageSize).applying(transform)
//        rect.origin = .zero
//
//        let format = UIGraphicsImageRendererFormat()
//        format.scale = 1
//
//        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
//
//        let image = renderer.image { renderContext in
//            renderContext.cgContext.translateBy(x: rect.midX, y: rect.midY)
//            renderContext.cgContext.rotate(by: rotationInRadians)
//
//            let x = options.contains(.flipOnVerticalAxis) ? -1.0 : 1.0
//            let y = options.contains(.flipOnHorizontalAxis) ? 1.0 : -1.0
//            renderContext.cgContext.scaleBy(x: CGFloat(x), y: CGFloat(y))
//
//            let drawRect = CGRect(origin: CGPoint(x: -cgImageSize.width / 2.0, y: -cgImageSize.height / 2.0), size: cgImageSize)
//            renderContext.cgContext.draw(cgImage, in: drawRect)
//        }
//
//        return image
//    }
//
    /// Rotates the image based on the information collected by the accelerometer
//    func withFixedOrientation() -> UIImage {
//        var imageAngle: Double = 0.0
//        
//        var shouldRotate = true
//        switch CaptureSession.current.editImageOrientation {
//        case .up:
//            shouldRotate = false
//        case .left:
//            imageAngle = Double.pi / 2
//        case .right:
//            imageAngle = -(Double.pi / 2)
//        case .down:
//            imageAngle = Double.pi
//        default:
//            shouldRotate = false
//        }
//        
//        if shouldRotate,
//            let finalImage = rotated(by: Measurement(value: imageAngle, unit: .radians)) {
//            return finalImage
//        } else {
//            return self
//        }
//    }
    
}
