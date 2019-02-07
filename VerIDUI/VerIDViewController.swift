//
//  VerIDViewController.swift
//  VerID
//
//  Created by Jakub Dolejs on 15/12/2015.
//  Copyright © 2015 Applied Recognition, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMedia
import ImageIO
import Accelerate
import SceneKit
import VerIDCore

public protocol VerIDViewControllerProtocol: class {
    var delegate: VerIDViewControllerDelegate? { get set }
    func imageScaleTransformAtImageSize(_ size: CGSize) -> CGAffineTransform
    func didProduceSessionResult(_ sessionResult: SessionResult, from faceDetectionResult: FaceDetectionResult)
    func drawCameraOverlay(bearing: Bearing, text: String?, isHighlighted: Bool, ovalBounds: CGRect, cutoutBounds: CGRect?, faceAngle: EulerAngle?, showArrow: Bool, offsetAngleFromBearing: EulerAngle?)
}

/**
 Base class for Ver-ID view controllers.
 
 Instead of using subclasses of `VerIDSession` you may instantiate or subclass one of the subclasses of `VerIDViewController` and present them in your view controller. This gives you more control over the layout and the running of registration or authentication but it's more difficult to implement.
 
 - See: `VerIDRegistrationViewController`
 `VerIDAuthenticationViewController`
 */
public class VerIDViewController: StillCameraViewController, ImageProviderService, VerIDViewControllerProtocol {
    
    public func dequeueImage() throws -> VerIDImage {
        var buffer: CMSampleBuffer?
        while buffer == nil {
            captureSessionQueue.sync {
                if let currentBuffer = self.currentSampleBuffer {
                    let status = CMSampleBufferCreateCopy(allocator: kCFAllocatorDefault, sampleBuffer: currentBuffer, sampleBufferOut: &buffer)
                    if status != 0 {
                        buffer = nil
                    }
                }
                self.currentSampleBuffer = nil
            }
        }
//        if buffer != nil {
            let orientation: CGImagePropertyOrientation
            switch self.imageOrientation {
            case .up:
                orientation = .up
            case .right:
                orientation = .right
            case .down:
                orientation = .down
            case .left:
                orientation = .left
            case .upMirrored:
                orientation = .upMirrored
            case .rightMirrored:
                orientation = .rightMirrored
            case .downMirrored:
                orientation = .downMirrored
            case .leftMirrored:
                orientation = .leftMirrored
            }
            return VerIDImage(sampleBuffer: buffer!, orientation: orientation)
//        } else {
//            // TODO
//            throw NSError(domain: "com.appliedrec.verid", code: 1, userInfo: nil)
//        }
    }
    
    
    /// The view that holds the camera feed.
    @IBOutlet var noCameraLabel: UILabel!
    @IBOutlet var directionLabel: PaddedRoundedLabel!
    @IBOutlet var sceneView: SCNView!
    @IBOutlet var directionLabelYConstraint: NSLayoutConstraint!
    @IBOutlet var overlayView: UIView!
    var sphereNode: SCNNode!
    
    // MARK: - Colours
    
    /// The colour behind the face 'cutout'
    let backgroundColour = UIColor(white: 0, alpha: 0.5)
    let highlightedColour = UIColor(red: 0.21176470588235, green: 0.68627450980392, blue: 0.0, alpha: 1.0)
    let highlightedTextColour = UIColor.white
    let neutralColour = UIColor.white
    let neutralTextColour = UIColor.black
    
    // MARK: -
    
    /// The Ver-ID view controller delegate
    public var delegate: VerIDViewControllerDelegate?
    /// Set this to distinguish between different view controllers if your delegate handles more than one Ver-ID view controller
    var identifier: String?
    
    var focusPointOfInterest: CGPoint? {
        didSet {
            if self.captureDevice != nil && self.captureDevice.isFocusModeSupported(.continuousAutoFocus) {
                do {
                    try self.captureDevice.lockForConfiguration()
                    if let pt = focusPointOfInterest {
                        self.captureDevice.focusPointOfInterest = pt
                    } else {
                        self.captureDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                    }
                    self.captureDevice.focusMode = .continuousAutoFocus
                    self.captureDevice.unlockForConfiguration()
                } catch {
                    
                }
            }
        }
    }
    var currentImageOrientation: UIImage.Orientation!
    var currentSampleBuffer: CMSampleBuffer?
    
    public init(nibName: String? = nil) {
        let nib = nibName ?? "VerIDViewController"
        super.init(nibName: nib, bundle: Bundle(for: type(of: self)))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Views
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.directionLabel.horizontalInset = 8.0
        self.directionLabel.layer.masksToBounds = true
        self.directionLabel.layer.cornerRadius = 10.0
        self.directionLabel.textColor = UIColor.black
        self.directionLabel.backgroundColor = UIColor.white
        self.noCameraLabel.isHidden = true
        self.currentImageOrientation = imageOrientation
        let bundle = Bundle(for: type(of: self))
        if let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            self.noCameraLabel.text = String(format: NSLocalizedString("Please go to settings and enable camera in the settings for app.", tableName: nil, bundle: bundle, value: "Please go to settings and enable camera in the settings for %@.", comment: "Instruction displayed to the user if they disable access to the camera"), appName)
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        directionLabel.isHidden = false
        let bundle = Bundle(for: type(of: self))
        directionLabel.text = NSLocalizedString("Preparing face detection", tableName: nil, bundle: bundle, value: "Preparing face detection", comment: "Displayed in the camera view when the app is preparing face detection")
        directionLabel.backgroundColor = UIColor.white
        sphereNode?.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        self.startCamera()
        let scene = SCNScene()
        sceneView.scene = scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // Orthographic projection
        cameraNode.camera!.usesOrthographicProjection = true
        cameraNode.camera!.orthographicScale = Double(view.bounds.height) / 2
        cameraNode.camera!.zFar = Double(view.bounds.width) * 10
        cameraNode.position = SCNVector3(x: 0, y: 0, z: Float(view.bounds.width))
        scene.rootNode.addChildNode(cameraNode)
        let sphere = SCNSphere(radius: view.bounds.width / 2)
        sphere.segmentCount = 100
        sphereNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(sphereNode)
        sphere.firstMaterial?.diffuse.contents = UIColor.clear
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.currentImageOrientation = imageOrientation
        coordinator.animateAlongsideTransition(in: self.view, animation: nil) { [weak self] context in
            guard self != nil else {
                return
            }
            if !context.isCancelled {
                // TODO: Set detected face view to
                // self.cameraPreviewView.frame.size
            }
        }
    }
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        self.stopCamera()
        super.viewWillDisappear(animated)
        self.navigationController?.isNavigationBarHidden = false
    }
    
    // MARK: -
    
    @IBAction func cancel(_ sender: Any? = nil) {
        self.stopCamera()
        self.delegate?.viewControllerDidCancel(self)
    }
    
    override func configureOutputs() {
        super.configureOutputs()
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: self.captureSessionQueue)
    }
    
    func didShowCameraAccessDeniedLabel() {
        
    }
    
    override func cameraBecameUnavailable(reason: String) {
        super.cameraBecameUnavailable(reason: reason)
        self.noCameraLabel.isHidden = false
        self.noCameraLabel.text = reason
        self.didShowCameraAccessDeniedLabel()
    }
    
    func removePreviewLayerSublayers() {
        if let previewLayer = self.cameraPreviewView?.videoPreviewLayer, let subs = previewLayer.sublayers {
            for sub in subs {
                if sub is CAShapeLayer {
                    sub.removeFromSuperlayer()
                }
            }
        }
    }
    
//    func logFaceDetectionResult(_ faceDetectionResult: FaceDetectionResult, sessionResult: SessionResult) {
//        if let eventLogService = self.eventLogService {
//            UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, false, UIScreen.main.scale)
//            defer {
//                UIGraphicsEndImageContext()
//            }
//            let rect = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
//            self.view.drawHierarchy(in: rect, afterScreenUpdates: true)
//            guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
//                return
//            }
//            eventLogService.addFaceDetectionResult(faceDetectionResult, sessionResult: sessionResult, image: image)
//        }
//    }
    
    public func didProduceSessionResult(_ sessionResult: SessionResult, from faceDetectionResult: FaceDetectionResult) {
        
    }
    
    // MARK: - Face and arrows
    
    public func drawCameraOverlay(bearing: Bearing, text: String?, isHighlighted: Bool, ovalBounds: CGRect, cutoutBounds: CGRect?, faceAngle: EulerAngle?, showArrow: Bool, offsetAngleFromBearing: EulerAngle?) {
        self.directionLabel.textColor = isHighlighted ? highlightedTextColour : neutralTextColour
        self.directionLabel.text = text
        self.directionLabel.backgroundColor = isHighlighted ? highlightedColour : neutralColour
        self.directionLabel.isHidden = text == nil
        
        self.directionLabelYConstraint.constant = max(ovalBounds.minY - self.directionLabel.frame.height - 16, 0)
        
        self.faceOvalLayer.setOvalBounds(ovalBounds, cutoutBounds: cutoutBounds, strokeColour: isHighlighted ? highlightedColour : neutralColour)
        if let angle = faceAngle, let offsetAngle = offsetAngleFromBearing, showArrow {
            self.drawArrowInFaceRect(ovalBounds, faceAngle: angle, requestedBearing: bearing, offsetAngleFromBearing: offsetAngle)
        } else {
            self.sphereNode?.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        }
    }
    
    private func drawArrowInFaceRect(_ rect: CGRect, faceAngle: EulerAngle, requestedBearing: Bearing, offsetAngleFromBearing: EulerAngle) {
        guard let sphere = self.sphereNode.geometry as? SCNSphere else {
            return
        }
        sphere.radius = rect.width / 2
        let size = CGSize(width: CGFloat.pi * 2 * sphere.radius, height: CGFloat.pi * sphere.radius)
        let translation = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
        let transform = CGAffineTransform(scaleX: size.width / 360, y: size.height / 180).concatenating(translation)
        let arrowTip: CGPoint
        let endAngle: CGFloat = 50
        let endAngle45deg: CGFloat = CGFloat(sin(Double.pi/4)) * endAngle
        switch requestedBearing {
        case .straight:
            arrowTip = CGPoint.zero.applying(translation)
        case .left:
            arrowTip = CGPoint(x: 0-endAngle, y: 0).applying(transform)
        case .leftUp:
            arrowTip = CGPoint(x: 0-endAngle45deg, y: 0-endAngle45deg/2).applying(transform)
        case .up:
            arrowTip = CGPoint(x: 0, y: 0-endAngle/2).applying(transform)
        case .rightUp:
            arrowTip = CGPoint(x: endAngle45deg, y: 0-endAngle45deg/2).applying(transform)
        case .right:
            arrowTip = CGPoint(x: endAngle, y: 0).applying(transform)
        case .rightDown:
            arrowTip = CGPoint(x: endAngle45deg, y: endAngle45deg/2).applying(transform)
        case .down:
            arrowTip = CGPoint(x: 0, y: endAngle/2).applying(transform)
        case .leftDown:
            arrowTip = CGPoint(x: 0-endAngle45deg, y: endAngle45deg/2)
        }
        let angle = atan2(CGFloat(0.0-offsetAngleFromBearing.pitch), CGFloat(offsetAngleFromBearing.yaw))
        let lineWidth = rect.width * 0.038
        let progress = hypot(CGFloat(offsetAngleFromBearing.yaw), CGFloat(0-offsetAngleFromBearing.pitch)) * 2
        let arrowLength = size.height * 0.15
        let arrowStemLength = min(max(arrowLength * progress, arrowLength * 0.75), arrowLength * 2.25)
        let arrowAngle = CGFloat(Measurement(value: 40, unit: UnitAngle.degrees).converted(to: .radians).value)
        let arrowPoint1 = CGPoint(x: arrowTip.x + cos(angle + CGFloat.pi - arrowAngle) * arrowLength * 0.6, y: arrowTip.y + sin(angle + CGFloat.pi - arrowAngle) * arrowLength * 0.6)
        let arrowPoint2 = CGPoint(x: arrowTip.x + cos(angle + CGFloat.pi + arrowAngle) * arrowLength * 0.6, y: arrowTip.y + sin(angle + CGFloat.pi + arrowAngle) * arrowLength * 0.6)
        let arrowStart = CGPoint(x: arrowTip.x + cos(angle + CGFloat.pi) * arrowStemLength, y: arrowTip.y + sin(angle + CGFloat.pi) * arrowStemLength)
        
        UIGraphicsBeginImageContext(size)
        if let context = UIGraphicsGetCurrentContext() {
            let layer = CAShapeLayer()
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.white.cgColor
            layer.lineCap = CAShapeLayerLineCap.round
            layer.lineJoin = CAShapeLayerLineJoin.round
            layer.lineWidth = lineWidth
            let path = UIBezierPath()
            path.move(to: arrowPoint1)
            path.addLine(to: arrowTip)
            path.addLine(to: arrowPoint2)
            path.move(to: arrowTip)
            path.addLine(to: arrowStart)
            layer.path = path.cgPath
            layer.render(in: context)
        }
        if let arrowImage = UIGraphicsGetImageFromCurrentImageContext() {
            sphere.firstMaterial?.diffuse.contents = arrowImage
        }
        UIGraphicsEndImageContext()
        self.sphereNode.position.x = Float(rect.midX - self.view.bounds.width / 2)
        self.sphereNode.position.y = Float(self.view.bounds.height / 2 - rect.midY)
        self.sphereNode.eulerAngles = SCNVector3(GLKMathDegreesToRadians(Float(faceAngle.pitch)*1.5), 0, 0)
    }
    
    private var faceOvalLayer: FaceOvalLayer {
        if let subs = self.overlayView.layer.sublayers, let faceLayer = subs.compactMap({ $0 as? FaceOvalLayer }).first {
            faceLayer.frame = self.overlayView.layer.bounds
            return faceLayer
        } else {
            let detectedFaceLayer = FaceOvalLayer(strokeColor: UIColor.black, backgroundColor: UIColor(white: 0, alpha: 0.5))
            //            detectedFaceLayer.text = self.faceOvalText
            self.overlayView.layer.addSublayer(detectedFaceLayer)
            detectedFaceLayer.frame = self.overlayView.layer.bounds
            return detectedFaceLayer
        }
    }
    
    // MARK: - Sample Capture
    
    /// Called when the camera returns an image
    ///
    /// - Parameters:
    ///   - output: output by which the image was collected
    ///   - sampleBuffer: image sample buffer
    ///   - connection: capture connection
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        currentSampleBuffer = sampleBuffer
        let rotation: CGFloat = CGFloat(Measurement(value: Double(self.videoRotation), unit: UnitAngle.degrees).converted(to: .radians).value)
        self.delegate?.viewController(self, didCaptureSampleBuffer: sampleBuffer, withRotation: rotation)
    }
    
    /// Affine transform to be used when scaling detected faces to fit the display
    ///
    /// - Parameter size: Size of the image where the face was detected
    /// - Returns: Affine transform to be used when scaling detected faces to fit the display
    public func imageScaleTransformAtImageSize(_ size: CGSize) -> CGAffineTransform {
        let rect = AVMakeRect(aspectRatio: self.overlayView.bounds.size, insideRect: CGRect(origin: CGPoint.zero, size: size))
        let scale = self.overlayView.bounds.width / rect.width
        var scaleTransform: CGAffineTransform = CGAffineTransform(translationX: 0-rect.minX, y: 0-rect.minY).concatenating(CGAffineTransform(scaleX: scale, y: scale))
        if self.captureDevice.position == .front {
            scaleTransform = scaleTransform.concatenating(CGAffineTransform(scaleX: -1, y: 1)).concatenating(CGAffineTransform(translationX: self.overlayView.bounds.width, y: 0))
        }
        return scaleTransform
    }
}
