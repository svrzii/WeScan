//
//  EditScanViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/12/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit
import AVFoundation

/// The `EditScanViewController` offers an interface for the user to edit the detected quadrilateral.
final class EditScanViewController: UIViewController {
	private var rotationAngle = Measurement<UnitAngle>(value: 0, unit: .degrees)
	private var enhancedImageIsAvailable = true
	private var isCurrentlyDisplayingEnhancedImage = false
	
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.isOpaque = true
        imageView.image = image
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var quadView: QuadrilateralView = {
        let quadView = QuadrilateralView()
        quadView.editable = true
        quadView.translatesAutoresizingMaskIntoConstraints = false
        return quadView
    }()
    
//    private lazy var nextButton: UIBarButtonItem = {
//        let button = UIBarButtonItem(title: NSLocalizedString("Next", comment: ""), style: .plain, target: self, action: #selector(pushReviewController))
//        button.tintColor = .white
//        return button
//    }()
	
	private lazy var enhanceButton: UIBarButtonItem = {
		let image = UIImage(systemName: "wand.and.rays.inverse", named: "enhance", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
		let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toggleEnhancedImage))
		button.tintColor = .white
		return button
	}()
	
	private lazy var rotateButton: UIBarButtonItem = {
		let image = UIImage(systemName: "rotate.right", named: "rotate", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
		let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(rotateImage))
		button.tintColor = .white
		return button
	}()
	
	private lazy var doneButton: UIBarButtonItem = {
		let button = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: self, action: #selector(finishScan))
		button.tintColor = navigationController?.navigationBar.tintColor
		return button
	}()
    
    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .plain, target: self, action: #selector(cancelButtonTapped))
		button.tintColor = .white
        return button
    }()
    
    /// The image the quadrilateral was detected on.
    private var image: UIImage
    
    /// The detected quadrilateral that can be edited by the user. Uses the image's coordinates.
    private var quad: Quadrilateral
    
    private var zoomGestureController: ZoomGestureController!
    
    private var quadViewWidthConstraint = NSLayoutConstraint()
    private var quadViewHeightConstraint = NSLayoutConstraint()
    
	private var results: ImageScannerResults?

    // MARK: - Life Cycle
    
    init(image: UIImage, quad: Quadrilateral?, rotateImage: Bool = true) {
        self.image = rotateImage ? image.applyingPortraitOrientation() : image
        self.quad = quad ?? EditScanViewController.defaultQuad(forImage: image)
		
		let ciImage = CIImage(image: self.image)
		let enhancedImage = ciImage?.applyingAdaptiveThreshold()
		let enhancedScan = enhancedImage.flatMap { ImageScannerScan(image: $0) }
		self.results = ImageScannerResults(detectedRectangle: self.quad, originalScan: ImageScannerScan(image: self.image), croppedScan: ImageScannerScan(image: self.image), enhancedScan: enhancedScan)

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
		
		navigationController?.navigationBar.tintColor = .white
		navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
		navigationController?.navigationBar.barTintColor = defaultAppColor
		navigationController?.navigationBar.backItem?.title = ""

        setupViews()
        setupConstraints()
		setupToolbar()
        title = NSLocalizedString("Crop", comment: "")
        navigationItem.rightBarButtonItem = doneButton
        if let firstVC = self.navigationController?.viewControllers.first, firstVC == self {
            navigationItem.leftBarButtonItem = cancelButton
        } else {
            navigationItem.leftBarButtonItem = nil
        }
        
        zoomGestureController = ZoomGestureController(image: image, quadView: quadView)
        
        let touchDown = UILongPressGestureRecognizer(target: zoomGestureController, action: #selector(zoomGestureController.handle(pan:)))
        touchDown.minimumPressDuration = 0
        view.addGestureRecognizer(touchDown)
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustQuadViewConstraints()
        displayQuad()
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Work around for an iOS 11.2 bug where UIBarButtonItems don't get back to their normal state after being pressed.
        navigationController?.navigationBar.tintAdjustmentMode = .normal
        navigationController?.navigationBar.tintAdjustmentMode = .automatic
		navigationController?.setToolbarHidden(true, animated: true)

    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		// We only show the toolbar (with the enhance button) if the enhanced image is available.
		if enhancedImageIsAvailable {
			navigationController?.setToolbarHidden(false, animated: true)
		}
	}
	
    // MARK: - Setups
    
    private func setupViews() {
        view.addSubview(imageView)
        view.addSubview(quadView)
    }
	
	private func setupToolbar() {
//		guard enhancedImageIsAvailable else { return }
		
		navigationController?.toolbar.barStyle = .blackTranslucent
		
		let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
		let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		toolbarItems = [fixedSpace, enhanceButton, flexibleSpace, rotateButton, fixedSpace]
	}
    
    private func setupConstraints() {
        let imageViewConstraints = [
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: imageView.leadingAnchor)
        ]
        
        quadViewWidthConstraint = quadView.widthAnchor.constraint(equalToConstant: 0.0)
        quadViewHeightConstraint = quadView.heightAnchor.constraint(equalToConstant: 0.0)
        
        let quadViewConstraints = [
            quadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            quadView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            quadViewWidthConstraint,
            quadViewHeightConstraint
        ]
        
        NSLayoutConstraint.activate(quadViewConstraints + imageViewConstraints)
    }
    
    // MARK: - Actions
    @objc func cancelButtonTapped() {
        if let imageScannerController = navigationController as? ImageScannerController {
            imageScannerController.imageScannerDelegate?.imageScannerControllerDidCancel(imageScannerController)
        }
    }
    
    @objc func pushReviewController() {
        guard let quad = quadView.quad,
            let ciImage = CIImage(image: image) else {
                if let imageScannerController = navigationController as? ImageScannerController {
                    let error = ImageScannerControllerError.ciImageCreation
                    imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
                }
                return
        }
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        let orientedImage = ciImage.oriented(forExifOrientation: Int32(cgOrientation.rawValue))
        let scaledQuad = quad.scale(quadView.bounds.size, image.size)
        self.quad = scaledQuad
        
        // Cropped Image
        var cartesianScaledQuad = scaledQuad.toCartesian(withHeight: image.size.height)
        cartesianScaledQuad.reorganize()
        
        let filteredImage = orientedImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesianScaledQuad.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesianScaledQuad.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesianScaledQuad.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesianScaledQuad.topRight)
        ])
        
        let croppedImage = UIImage.from(ciImage: filteredImage)
        // Enhanced Image
        let enhancedImage = filteredImage.applyingAdaptiveThreshold()?.withFixedOrientation()
        let enhancedScan = enhancedImage.flatMap { ImageScannerScan(image: $0) }
        
        let results = ImageScannerResults(detectedRectangle: scaledQuad, originalScan: ImageScannerScan(image: image), croppedScan: ImageScannerScan(image: croppedImage), enhancedScan: enhancedScan)
        
        let reviewViewController = ReviewViewController(results: results)
		navigationController?.navigationBar.backItem?.title = ""
        navigationController?.pushViewController(reviewViewController, animated: true)
    }
	
	@objc func toggleEnhancedImage() {
		guard enhancedImageIsAvailable else { return }
		
		isCurrentlyDisplayingEnhancedImage.toggle()
		
		if isCurrentlyDisplayingEnhancedImage {
			enhanceButton.tintColor = .yellow
		} else {
			enhanceButton.tintColor = .white
		}
		
		if enhancedImageIsAvailable, isCurrentlyDisplayingEnhancedImage {
			self.imageView.image = self.results?.enhancedScan?.image
		} else {
			self.imageView.image = self.results?.originalScan.image
		}
	}
	
	@objc func rotateImage() {
		rotationAngle.value += 90
		
		if rotationAngle.value == 360 {
			rotationAngle.value = 0
		}
		
		if let enhancedScanRotation = self.results?.enhancedScan?.image.rotated(by: rotationAngle), let croppedScanScanRotation = self.results?.croppedScan.image.rotated(by: rotationAngle), let originalScanRotation = self.results?.originalScan.image.rotated(by: rotationAngle), let image = self.image.rotated(by: rotationAngle) {
			self.results?.enhancedScan?.image = enhancedScanRotation
			self.results?.croppedScan.image = croppedScanScanRotation
			self.results?.originalScan.image = originalScanRotation
			self.image = image
		}
		
		if enhancedImageIsAvailable, isCurrentlyDisplayingEnhancedImage {
			self.imageView.image = self.results?.enhancedScan?.image
		} else {
			self.imageView.image = self.results?.originalScan.image
		}
	}
	
	@objc private func finishScan() {
		guard let quad = quadView.quad,
			  let ciImage = CIImage(image: image) else {
			if let imageScannerController = navigationController as? ImageScannerController {
				let error = ImageScannerControllerError.ciImageCreation
				imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
			}
			return
		}
		let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
		let orientedImage = ciImage.oriented(forExifOrientation: Int32(cgOrientation.rawValue))
		let scaledQuad = quad.scale(quadView.bounds.size, image.size)
		self.quad = scaledQuad
		
		// Cropped Image
		var cartesianScaledQuad = scaledQuad.toCartesian(withHeight: image.size.height)
		cartesianScaledQuad.reorganize()
		
		let filteredImage = orientedImage.applyingFilter("CIPerspectiveCorrection", parameters: [
			"inputTopLeft": CIVector(cgPoint: cartesianScaledQuad.bottomLeft),
			"inputTopRight": CIVector(cgPoint: cartesianScaledQuad.bottomRight),
			"inputBottomLeft": CIVector(cgPoint: cartesianScaledQuad.topLeft),
			"inputBottomRight": CIVector(cgPoint: cartesianScaledQuad.topRight)
		])
		
		let croppedImage = UIImage.from(ciImage: filteredImage)
		// Enhanced Image
		let enhancedImage = filteredImage.applyingAdaptiveThreshold()?.withFixedOrientation()
		let enhancedScan = enhancedImage.flatMap { ImageScannerScan(image: $0) }
		
		var newResults = ImageScannerResults(detectedRectangle: scaledQuad, originalScan: ImageScannerScan(image: image), croppedScan: ImageScannerScan(image: croppedImage), enhancedScan: enhancedScan)
		self.results = newResults
		
		guard let imageScannerController = navigationController as? ImageScannerController else { return }
		newResults.doesUserPreferEnhancedScan = isCurrentlyDisplayingEnhancedImage
		imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFinishScanningWithResults: newResults)
	}
	
    private func displayQuad() {
        let imageSize = image.size
        let imageFrame = CGRect(origin: quadView.frame.origin, size: CGSize(width: quadViewWidthConstraint.constant, height: quadViewHeightConstraint.constant))
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: imageSize, aspectFillInSize: imageFrame.size)
        let transforms = [scaleTransform]
        let transformedQuad = quad.applyTransforms(transforms)
        
        quadView.drawQuadrilateral(quad: transformedQuad, animated: false)
    }
    
    /// The quadView should be lined up on top of the actual image displayed by the imageView.
    /// Since there is no way to know the size of that image before run time, we adjust the constraints to make sure that the quadView is on top of the displayed image.
    private func adjustQuadViewConstraints() {
        let frame = AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
        quadViewWidthConstraint.constant = frame.size.width
        quadViewHeightConstraint.constant = frame.size.height
    }
    
    /// Generates a `Quadrilateral` object that's centered and 90% of the size of the passed in image.
    private static func defaultQuad(forImage image: UIImage) -> Quadrilateral {
        let topLeft = CGPoint(x: image.size.width * 0.05, y: image.size.height * 0.05)
        let topRight = CGPoint(x: image.size.width * 0.95, y: image.size.height * 0.05)
        let bottomRight = CGPoint(x: image.size.width * 0.95, y: image.size.height * 0.95)
        let bottomLeft = CGPoint(x: image.size.width * 0.05, y: image.size.height * 0.95)
        
        let quad = Quadrilateral(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
        
        return quad
    }
    
}
