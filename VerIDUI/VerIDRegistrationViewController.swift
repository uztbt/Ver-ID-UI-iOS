//
//  VerIDRegistrationViewController.swift
//  VerID
//
//  Created by Jakub Dolejs on 07/06/2018.
//  Copyright © 2018 Applied Recognition, Inc. All rights reserved.
//

import UIKit
import VerIDCore

/// Subclass of `VerIDViewController` that displays faces collected during the session
class VerIDRegistrationViewController: VerIDViewController {

    @IBOutlet var detectedFaceStackView: UIStackView!
    
    var requestedBearing: Bearing?
    
    public init() {
        super.init(nibName: "VerIDRegistrationViewController")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let delegate = self.delegate else {
            return
        }
        for _ in 0..<delegate.settings.numberOfResultsToCollect {
            let imageView = createImageView()
            detectedFaceStackView.addArrangedSubview(imageView)
        }
    }
    
    override func drawFaceFromResult(_ faceDetectionResult: FaceDetectionResult, sessionResult: SessionResult, defaultFaceBounds: CGRect, offsetAngleFromBearing: EulerAngle?) {
        super.drawFaceFromResult(faceDetectionResult, sessionResult: sessionResult, defaultFaceBounds: defaultFaceBounds, offsetAngleFromBearing: offsetAngleFromBearing)
        guard sessionResult.error == nil && (requestedBearing == nil || requestedBearing! != faceDetectionResult.requestedBearing || faceDetectionResult.status == .faceAligned) else {
            return
        }
        requestedBearing = faceDetectionResult.requestedBearing
        let imageName: String
        switch faceDetectionResult.requestedBearing {
        case .straight:
            imageName = "head_thumbnail_straight"
        case .up:
            imageName = "head_thumbnail_up"
        case .rightUp:
            imageName = "head_thumbnail_righ_up"
        case .right:
            imageName = "head_thumbnail_right"
        case .rightDown:
            imageName = "head_thumbnail_right_down"
        case .down:
            imageName = "head_thumbnail_down"
        case .leftDown:
            imageName = "head_thumbnail_left_down"
        case .left:
            imageName = "head_thumbnail_left"
        case .leftUp:
            imageName = "head_thumbnail_left_up"
        }
        let bundle = Bundle(for: type(of: self))
        guard let image = UIImage(named: imageName, in: bundle, compatibleWith: nil) else {
            return
        }
        guard let settings = self.delegate?.settings else {
            return
        }
        for i in 0..<settings.numberOfResultsToCollect {
            guard let imageView = detectedFaceStackView.arrangedSubviews[i] as? UIImageView else {
                return
            }
            for sub in imageView.subviews {
                sub.removeFromSuperview()
            }
            let viewSize = imageView.frame.size
            let images: [UIImage] = sessionResult.attachments.compactMap({
                guard $0.bearing == self.requestedBearing else {
                    return nil
                }
                guard let path = $0.imageURL?.path, let image = UIImage(contentsOfFile: path) else {
                    return nil
                }
                let originalBounds = $0.face.bounds
                var scaledBoundsSize = CGSize(width: originalBounds.width, height: originalBounds.height)
                if viewSize.width / viewSize.height > originalBounds.width / originalBounds.height {
                    // View is "fatter" match widths
                    scaledBoundsSize.width = viewSize.width
                    scaledBoundsSize.height = viewSize.width / originalBounds.width * originalBounds.height
                } else {
                    scaledBoundsSize.height = viewSize.height
                    scaledBoundsSize.width = viewSize.height / originalBounds.height * originalBounds.width
                }
                let transform = CGAffineTransform(scaleX: scaledBoundsSize.width / originalBounds.width, y: scaledBoundsSize.height / originalBounds.height)
                let bounds = $0.face.bounds.applying(transform)
                let imageTransform = CGAffineTransform(scaleX: scaledBoundsSize.width / originalBounds.width, y: scaledBoundsSize.height / originalBounds.height)
                let scaledImageSize = image.size.applying(imageTransform)
                UIGraphicsBeginImageContext(bounds.size)
                defer {
                    UIGraphicsEndImageContext()
                }
                image.draw(in: CGRect(x: 0-bounds.minX, y: 0-bounds.minY, width: scaledImageSize.width, height: scaledImageSize.height))
//                image.draw(at: CGPoint(x: 0-bounds.minX, y: 0-bounds.minY))
                return UIGraphicsGetImageFromCurrentImageContext()
            })
            if i<images.count {
                imageView.alpha = 1
                imageView.image = images[i]
                imageView.transform = CGAffineTransform(scaleX: -1, y: 1)
            } else {
                imageView.alpha = 0.5
                imageView.image = image
                imageView.transform = CGAffineTransform.identity
            }
            if i+1 == images.count {
                let activityIndicatorView = UIActivityIndicatorView(frame: detectedFaceStackView.arrangedSubviews[i].bounds)
                activityIndicatorView.startAnimating()
                imageView.addSubview(activityIndicatorView)
            }
        }
    }
    
    func createImageView() -> UIImageView {
        let imageView = UIImageView(image: nil)
        let constraint = NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: imageView, attribute: .height, multiplier: 4/5, constant: 0)
        imageView.addConstraint(constraint)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        return imageView
    }

}
