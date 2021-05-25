//
//  ZoomGestureController.swift
//  WeScan
//
//  Created by Bobo on 5/31/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

final class ZoomGestureController {
    
    private let image: UIImage
    private let quadView: QuadrilateralView
    private var previousPanPosition: CGPoint?
    private var closestCorner: CornerPosition?

    init(image: UIImage, quadView: QuadrilateralView) {
        self.image = image
        self.quadView = quadView
    }

    @objc func handle(pan: UIGestureRecognizer) {
        guard let drawnQuad = quadView.quad else {
            return
        }
        
        guard pan.state != .ended else {
            self.previousPanPosition = nil
            self.closestCorner = nil
            quadView.resetHighlightedCornerViews()
            return
        }
        
        let position = pan.location(in: quadView)
        
        let previousPanPosition = self.previousPanPosition ?? position
        let closestCorner = self.closestCorner ?? position.closestCornerFrom(quad: drawnQuad)
		if closestCorner == .topMiddle {
			let topLeftCornerView = quadView.cornerViewForCornerPosition(position: .topLeft)
			let topRightCornerView = quadView.cornerViewForCornerPosition(position: .topRight)
			let topLeftCenter = CGPoint(x: topLeftCornerView.center.x + position.x - previousPanPosition.x, y: topLeftCornerView.center.y + position.y - previousPanPosition.y)
			let topRightCenter = CGPoint(x: topRightCornerView.center.x + position.x - previousPanPosition.x, y: topRightCornerView.center.y + position.y - previousPanPosition.y)
			
			quadView.moveCorner(cornerView: topLeftCornerView, atPoint: topLeftCenter)
			quadView.moveCorner(cornerView: topRightCornerView, atPoint: topRightCenter)
		} else if closestCorner == .bottomMiddle {
			let bottomLeftCornerView = quadView.cornerViewForCornerPosition(position: .bottomLeft)
			let bottomRightCornerView = quadView.cornerViewForCornerPosition(position: .bottomRight)
			let bottomLeftCenter = CGPoint(x: bottomLeftCornerView.center.x + position.x - previousPanPosition.x, y: bottomLeftCornerView.center.y + position.y - previousPanPosition.y)
			let bottomRightCenter = CGPoint(x: bottomRightCornerView.center.x + position.x - previousPanPosition.x, y: bottomRightCornerView.center.y + position.y - previousPanPosition.y)
			
			quadView.moveCorner(cornerView: bottomLeftCornerView, atPoint: bottomLeftCenter)
			quadView.moveCorner(cornerView: bottomRightCornerView, atPoint: bottomRightCenter)
		} else if closestCorner == .leftMiddle {
			let topLeftCornerView = quadView.cornerViewForCornerPosition(position: .topLeft)
			let bottomLeftCornerView = quadView.cornerViewForCornerPosition(position: .bottomLeft)
			let topLeftCenter = CGPoint(x: topLeftCornerView.center.x + position.x - previousPanPosition.x, y: topLeftCornerView.center.y + position.y - previousPanPosition.y)
			let bottomLeftCenter = CGPoint(x: bottomLeftCornerView.center.x + position.x - previousPanPosition.x, y: bottomLeftCornerView.center.y + position.y - previousPanPosition.y)
			
			quadView.moveCorner(cornerView: topLeftCornerView, atPoint: topLeftCenter)
			quadView.moveCorner(cornerView: bottomLeftCornerView, atPoint: bottomLeftCenter)
		} else if closestCorner == .rightMiddle {
			let bottomRightCornerView = quadView.cornerViewForCornerPosition(position: .bottomRight)
			let topRightCornerView = quadView.cornerViewForCornerPosition(position: .topRight)
			let bottomRightCenter = CGPoint(x: bottomRightCornerView.center.x + position.x - previousPanPosition.x, y: bottomRightCornerView.center.y + position.y - previousPanPosition.y)
			let topRightCenter = CGPoint(x: topRightCornerView.center.x + position.x - previousPanPosition.x, y: topRightCornerView.center.y + position.y - previousPanPosition.y)
			
			quadView.moveCorner(cornerView: bottomRightCornerView, atPoint: bottomRightCenter)
			quadView.moveCorner(cornerView: topRightCornerView, atPoint: topRightCenter)
		} else {
			let offset = CGAffineTransform(translationX: position.x - previousPanPosition.x, y: position.y - previousPanPosition.y)
			let cornerView = quadView.cornerViewForCornerPosition(position: closestCorner)
			let draggedCornerViewCenter = cornerView.center.applying(offset)
			
			quadView.moveCorner(cornerView: cornerView, atPoint: draggedCornerViewCenter)
		}
		
		
//		let offset = CGAffineTransform(translationX: position.x - previousPanPosition.x, y: position.y - previousPanPosition.y)
//		let cornerView = quadView.cornerViewForCornerPosition(position: closestCorner)
//		let draggedCornerViewCenter = cornerView.center.applying(offset)
//		
//		let scale = image.size.width / quadView.bounds.size.width
//		let scaledDraggedCornerViewCenter = CGPoint(x: draggedCornerViewCenter.x * scale, y: draggedCornerViewCenter.y * scale)
//		guard let zoomedImage = image.scaledImage(atPoint: scaledDraggedCornerViewCenter, scaleFactor: 2.5, targetSize: quadView.bounds.size) else {
//			return
//		}
//		
//		quadView.highlightCornerAtPosition(position: closestCorner, with: zoomedImage)
        
        self.previousPanPosition = position
        self.closestCorner = closestCorner
        
        
    }
    
}
