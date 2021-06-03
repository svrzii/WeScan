//
//  ScannerViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit
import AVFoundation

/// The `ScannerViewController` offers an interface to give feedback to the user regarding quadrilaterals that are detected. It also gives the user the opportunity to capture an image with a detected rectangle.
public final class ScannerViewController: UIViewController {
	private var defaultColor = UIColor.black
    private var captureSessionManager: CaptureSessionManager?
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView!
    
    /// The view that draws the detected rectangles.
    private let quadView = QuadrilateralView()
        
    /// Whether flash is enabled
    private var flashEnabled = false
    
    /// The original bar style that was set by the host app
    private var originalBarStyle: UIBarStyle?
    
	private var cameraView: UIView?
	
    private lazy var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton()
		button.setTitle(NSLocalizedString("Cancel", comment: "The cancel button"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancelImageScannerController), for: .touchUpInside)
        return button
    }()
    
    private lazy var autoScanButton: UIBarButtonItem = {
        let title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(toggleAutoScan))
        button.tintColor = .white
        
        return button
    }()
    
    private lazy var flashButton: UIBarButtonItem = {
        let image = UIImage(systemName: "bolt.fill", named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toggleFlash))
        button.tintColor = .white
        
        return button
    }()
	
	private lazy var photosButton: UIBarButtonItem = {
		let image = UIImage(named: "ic_gallery", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
		let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(openPhotos))
		button.tintColor = .white
		
		return button
	}()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    // MARK: - Life Cycle

	
	public func updateColor(color: UIColor) {
		defaultColor = color
		view.backgroundColor = color
		quadView.strokeColor = color.cgColor
	}

    override public func viewDidLoad() {
        super.viewDidLoad()
        
		title = NSLocalizedString("Scanning", comment: "")
        view.backgroundColor = UIColor.black

        setupViews()
        setupNavigationBar()
        setupConstraints()
		self.view.layoutIfNeeded()

        captureSessionManager = CaptureSessionManager(videoPreviewLayer: videoPreviewLayer, delegate: self)
        
        originalBarStyle = navigationController?.navigationBar.barStyle
        
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }
	
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        
        CaptureSession.current.isEditing = false
        quadView.removeQuadrilateral()
        captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true
        
        navigationController?.navigationBar.barStyle = .blackTranslucent
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
		if let cameraView = self.cameraView {
			self.videoPreviewLayer.frame = cameraView.layer.bounds
		}
    }
	
	public override func viewWillLayoutSubviews() {
		
		if let cameraView = self.cameraView {
			self.videoPreviewLayer.frame = cameraView.layer.bounds
		}
	}
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = originalBarStyle ?? .default
        captureSessionManager?.stop()
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        if device.torchMode == .on {
            toggleFlash()
        }
    }
    
    // MARK: - Setups
    
    private func setupViews() {
		let cameraView = UIView()
		cameraView.translatesAutoresizingMaskIntoConstraints = false
		cameraView.backgroundColor = .black
		cameraView.layer.addSublayer(videoPreviewLayer)
		self.cameraView = cameraView
		view.addSubview(cameraView)
		
		view.backgroundColor = .black
		quadView.translatesAutoresizingMaskIntoConstraints = false
		quadView.editable = false
		
		cameraView.addSubview(quadView)
		view.addSubview(cancelButton)
		view.addSubview(shutterButton)
		view.addSubview(activityIndicator)
    }
    
    private func setupNavigationBar() {
		navigationController?.interactivePopGestureRecognizer?.isEnabled = false
		navigationItem.setLeftBarButtonItems([flashButton, photosButton], animated: false)
//        navigationItem.setRightBarButton(autoScanButton, animated: false)
        
        if UIImagePickerController.isFlashAvailable(for: .rear) == false {
            let flashOffImage = UIImage(systemName: "bolt.slash.fill", named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
            flashButton.image = flashOffImage
            flashButton.tintColor = UIColor.lightGray
        }
    }
    
	private func setupConstraints() {
		var quadViewConstraints = [NSLayoutConstraint]()
		var cancelButtonConstraints = [NSLayoutConstraint]()
		var shutterButtonConstraints = [NSLayoutConstraint]()
		var activityIndicatorConstraints = [NSLayoutConstraint]()
		var cameraViewConstraints = [NSLayoutConstraint]()
		
		guard let cameraView = self.cameraView else {
			return
			
		}
		
		var safeAreaBottom: CGFloat = 0
		if #available(iOS 13.0, *) {
			let window = UIApplication.shared.windows[0]
			safeAreaBottom = window.safeAreaInsets.bottom
		} else if #available(iOS 11.0, *), let keyWindow = UIApplication.shared.keyWindow {
			safeAreaBottom = keyWindow.safeAreaInsets.bottom
		}
		
		if safeAreaBottom > 0.0 {
			cameraViewConstraints = [
				cameraView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
				view.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: 150)
				
			]
		} else {
			cameraViewConstraints = [
				cameraView.topAnchor.constraint(equalTo: view.topAnchor, constant: 35),
				view.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: 100)
			]
		}
		
		cameraViewConstraints.append(view.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor))
		cameraViewConstraints.append(cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor))
		
		quadViewConstraints = [
			quadView.topAnchor.constraint(equalTo: cameraView.topAnchor),
			cameraView.bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
			cameraView.trailingAnchor.constraint(equalTo: quadView.trailingAnchor),
			quadView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor)
		]
		
		shutterButtonConstraints = [
			shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			shutterButton.widthAnchor.constraint(equalToConstant: 65.0),
			shutterButton.heightAnchor.constraint(equalToConstant: 65.0)
		]
		
		activityIndicatorConstraints = [
			activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
		]
		
		if #available(iOS 11.0, *) {
			cancelButtonConstraints = [
				cancelButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 24.0),
				view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: (65.0 / 2) - 10.0)
			]
			
			let shutterButtonBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
			shutterButtonConstraints.append(shutterButtonBottomConstraint)
		} else {
			cancelButtonConstraints = [
				cancelButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 24.0),
				view.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: (65.0 / 2) - 10.0)
			]
			
			let shutterButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
			shutterButtonConstraints.append(shutterButtonBottomConstraint)
		}
		
		NSLayoutConstraint.activate(cameraViewConstraints + quadViewConstraints + cancelButtonConstraints + shutterButtonConstraints + activityIndicatorConstraints)
	}
    
    // MARK: - Tap to Focus
    
    /// Called when the AVCaptureDevice detects that the subject area has changed significantly. When it's called, we reset the focus so the camera is no longer out of focus.
    @objc private func subjectAreaDidChange() {
        /// Reset the focus and exposure back to automatic
        do {
            try CaptureSession.current.resetFocusToAuto()
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
        
        /// Remove the focus rectangle if one exists
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: true)
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard  let touch = touches.first else { return }
        let touchPoint = touch.location(in: view)
        let convertedTouchPoint: CGPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: false)
        
        focusRectangle = FocusRectangleView(touchPoint: touchPoint)
        view.addSubview(focusRectangle)
        
        do {
            try CaptureSession.current.setFocusPointToTapPoint(convertedTouchPoint)
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
    }
    
    // MARK: - Actions
    
    @objc private func captureImage(_ sender: UIButton) {
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }
    
    @objc private func toggleAutoScan() {
        if CaptureSession.current.isAutoScanEnabled {
            CaptureSession.current.isAutoScanEnabled = false
            autoScanButton.title = NSLocalizedString("wescan.scanning.manual", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Manual", comment: "The manual button state")
        } else {
            CaptureSession.current.isAutoScanEnabled = true
            autoScanButton.title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        }
    }
    
    @objc private func toggleFlash() {
        let state = CaptureSession.current.toggleFlash()
        
        let flashImage = UIImage(systemName: "bolt.fill", named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        let flashOffImage = UIImage(systemName: "bolt.slash.fill", named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        
        switch state {
        case .on:
            flashEnabled = true
            flashButton.image = flashImage
            flashButton.tintColor = .yellow
        case .off:
            flashEnabled = false
            flashButton.image = flashImage
            flashButton.tintColor = .white
        case .unknown, .unavailable:
            flashEnabled = false
            flashButton.image = flashOffImage
            flashButton.tintColor = UIColor.lightGray
        }
    }
	
	@objc private func openPhotos() {
		let imagePicker = UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.sourceType = .photoLibrary
		present(imagePicker, animated: true)
	}
    
    @objc private func cancelImageScannerController() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerControllerDidCancel(imageScannerController)
    }
    
}

extension ScannerViewController: RectangleDetectionDelegateProtocol {
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        
        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true
        
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
    }
    
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        captureSessionManager.stop()
        shutterButton.isUserInteractionEnabled = false
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
        activityIndicator.stopAnimating()
        
        let editVC = EditScanViewController(image: picture, quad: quad)
        navigationController?.pushViewController(editVC, animated: false)
        
        shutterButton.isUserInteractionEnabled = true
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad = quad else {
            // If no quad has been detected, we remove the currently displayed on on the quadView.
            quadView.removeQuadrilateral()
            return
        }
        
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)

        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)

        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: quadView.bounds)
        
        let transforms = [scaleTransform, rotationTransform, translationTransform]
        
        let transformedQuad = quad.applyTransforms(transforms)
        
        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }
    
}

extension ScannerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true)
	}
	
	public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
		picker.dismiss(animated: true)
		
		guard let originalImage = info[.originalImage] as? UIImage  else { return }
		
		let image = originalImage.fixedOrientation
		guard let imageScannerController = navigationController as? ImageScannerController else { return }

		// If an image was passed in by the host app (e.g. picked from the photo library), use it instead of the document scanner.
		imageScannerController.detect(image: image) { [weak imageScannerController] detectedQuad in
			let editVC = EditScanViewController(image: image, quad: detectedQuad)
			imageScannerController?.navigationBar.backItem?.title = ""
			imageScannerController?.pushViewController(editVC, animated: false)
		}
	}
}
