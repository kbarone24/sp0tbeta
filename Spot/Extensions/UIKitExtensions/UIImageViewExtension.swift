//
//  UIImageViewExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

extension UIImageView {
    
    func animateGIF(directionUp: Bool, counter: Int) {
        
        if superview == nil || isHidden || animationImages?.isEmpty ?? true { self.stopPostAnimation(); return }
        
        var newDirection = directionUp
        var newCount = counter
        
        if let postImage = self as? PostImageView { postImage.animationIndex = newCount; postImage.activeAnimation = true }
        /// for smooth animations on likes / other table reloads
        
        if directionUp {
            if counter == (animationImages?.count ?? 0) - 1 {
                newDirection = false
                newCount = (animationImages?.count ?? 0) - 2
            } else {
                newCount += 1
            }
        } else {
            if counter == 0 {
                newDirection = true
                newCount = 1
            } else {
                newCount -= 1
            }
        }
        
        let duration: TimeInterval = 0.049
        
        UIView.transition(with: self, duration: duration, options: [.allowUserInteraction, .beginFromCurrentState]) { [weak self] in
            guard let self else { return }
            
            if self.animationImages?.isEmpty ?? true || counter >= self.animationImages?.count ?? 0 {
                self.stopPostAnimation()
                return
            }
            
            if self.animationImages?.count ?? 0 > counter {
                self.image = self.animationImages?[counter]
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.005) { [weak self] in
            self?.animateGIF(directionUp: newDirection, counter: newCount)
        }
    }
    
    func stopPostAnimation() {
        if let postImage = self as? PostImageView {
            postImage.animationIndex = 0
            postImage.activeAnimation = false
        }
    }
    
    func animate5FrameAlive(directionUp: Bool, counter: Int) {
        
        if superview == nil || isHidden || animationImages?.isEmpty ?? true { return }
        
        var newDirection = directionUp
        var newCount = counter
        
        if directionUp {
            if counter == 4 {
                newDirection = false
                newCount = 3
            } else {
                newCount += 1
            }
        } else {
            if counter == 0 {
                newDirection = true
                newCount = 1
            } else {
                newCount -= 1
            }
        }
        
        UIView.transition(with: self, duration: 0.08, options: [.allowUserInteraction, .beginFromCurrentState]) { [weak self] in
            guard let self = self else { return }
            
            if self.animationImages?.isEmpty ?? true {
                return
            }
            
            if counter >= self.animationImages?.count ?? 0 {
                return
            }
            
            self.image = self.animationImages?[counter]
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.085) { [weak self] in
            guard let self = self else { return }
            self.animate5FrameAlive(directionUp: newDirection, counter: newCount)
        }
    }
    
    func roundCornersForAspectFit(radius: CGFloat) {
        guard let image else { return }
        
        // calculate drawingRect
        let boundsScale = bounds.size.width / bounds.size.height
        let imageScale = image.size.width / image.size.height
        
        var drawingRect: CGRect = bounds
        
        if boundsScale > imageScale {
            drawingRect.size.width = drawingRect.size.height * imageScale
            drawingRect.origin.x = (bounds.size.width - drawingRect.size.width) / 2
            
        } else {
            drawingRect.size.height = drawingRect.size.width / imageScale
            drawingRect.origin.y = (bounds.size.height - drawingRect.size.height) / 2
        }
        
        let path = UIBezierPath(roundedRect: drawingRect, cornerRadius: radius)
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }
    
    func getImageLayoutValues(imageAspect: CGFloat) -> (imageHeight: CGFloat, bottomConstraint: CGFloat) {
        let statusHeight = getStatusHeight()
        let maxHeight = UserDataModel.shared.maxAspect * UIScreen.main.bounds.width
        let minY: CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let maxY = minY + maxHeight
        let midY = maxY - 86
        let currentHeight = getImageHeight(aspectRatio: imageAspect, maxAspect: UserDataModel.shared.maxAspect)
        let imageBottom: CGFloat = imageAspect > 1.45 ? maxY : imageAspect > 1.1 ? midY : (minY + maxY + currentHeight) / 2 - 15
        let bottomConstraint = UIScreen.main.bounds.height - imageBottom
        return (currentHeight, bottomConstraint)
    }
    
    func getImageHeight(aspectRatio: CGFloat, maxAspect: CGFloat) -> CGFloat {
        var imageAspect = min(aspectRatio, maxAspect)
        imageAspect = getRoundedAspectRatio(aspect: imageAspect)
        let imageHeight = UIScreen.main.bounds.width * imageAspect
        return imageHeight
    }
    
    func getRoundedAspectRatio(aspect: CGFloat) -> CGFloat {
        var imageAspect = aspect
        if imageAspect > 1.1 && imageAspect < 1.45 { imageAspect = 1.333 } /// stretch iPhone vertical
        else if imageAspect > 1.45 { imageAspect = UserDataModel.shared.maxAspect } /// round to max aspect
        return imageAspect
    }
}
