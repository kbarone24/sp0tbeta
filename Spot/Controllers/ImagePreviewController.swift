//
//  ImagePreviewController.swift
//  Spot
//
//  Created by kbarone on 2/27/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import Firebase
import Mixpanel
import CoreLocation
import IQKeyboardManagerSwift
import SnapKit

class ImagePreviewController: UIViewController {
    
    var spotObject: MapSpot!
                
    var currentImage: PostImagePreview!
    var nextImage: PostImagePreview!
    var previousImage: PostImagePreview!
    var previewBackground: UIView! /// tracks where detail view will be added
    
    var backButton: UIButton!
    var dotView: UIView!
    var chooseMapButton: ChooseMapButton!
    var draftsButton: UIButton!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        
    /// detailView
    var postDetailView: PostDetailView!
    var spotNameButton: SpotNameButton!
    var addedUsersView: AddedUsersView!
    
    var cancelOnDismiss = false
    var cameraObject: ImageObject!
    
    var panGesture: UIPanGestureRecognizer! /// swipe down to close keyboard
    
    var textView: UITextView!
    let textViewPlaceholder = "What's up..."
    var shouldRepositionTextView = false /// keyboardWillShow firing late -> this variable tells keyboardWillChange whether to reposition
    var snapBottomConstraintToImage = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cancelOnDismiss = false
        /// set hidden for smooth transition
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CameraPreviewOpen")
        IQKeyboardManager.shared.enable = false /// disable for textView sticking to keyboard
        setUpNavBar()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelOnDismiss = true
        IQKeyboardManager.shared.enable = true
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setPostInfo()
        addPreviewView()
        addPostDetail()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    func setUpNavBar() {
                
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.removeBackgroundImage()
        navigationController?.navigationBar.removeShadow()
        
        navigationItem.hidesBackButton = true
    }
    
    func setPostInfo() {
        
        var post = UploadPostModel.shared.postObject!
        
        var selectedImages: [UIImage] = []
        var frameCounter = 0
        var frameIndexes: [Int] = []
        var aspectRatios: [CGFloat] = []
        var imageLocations: [[String: Double]] = []
        if cameraObject != nil { UploadPostModel.shared.selectedObjects.append(cameraObject) }
        
        /// cycle through selected imageObjects and find individual sets of images / frames
        for obj in UploadPostModel.shared.selectedObjects {
            let location = locationIsEmpty(location: obj.rawLocation) ? UserDataModel.shared.currentLocation : obj.rawLocation
            imageLocations.append(["lat" : location!.coordinate.latitude, "long": location!.coordinate.longitude])
           
            let images = obj.gifMode ? obj.animationImages : [obj.stillImage]
            selectedImages.append(contentsOf: images)
            frameIndexes.append(frameCounter)
            aspectRatios.append(selectedImages[frameCounter].size.height/selectedImages[frameCounter].size.width)

            frameCounter += images.count
        }
        
        post.frameIndexes = frameIndexes
        post.aspectRatios = aspectRatios
        post.postImage = selectedImages
        post.imageLocations = imageLocations
        
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.9
        post.imageHeight = getImageHeight(aspectRatios: post.aspectRatios ?? [], maxAspect: cameraAspect)
        
        let imageLocation = UploadPostModel.shared.selectedObjects.first?.rawLocation ?? UserDataModel.shared.currentLocation ?? CLLocation()
        if !locationIsEmpty(location: imageLocation) {
            post.postLat = imageLocation.coordinate.latitude
            post.postLong = imageLocation.coordinate.longitude
            UploadPostModel.shared.setPostCity()
        }
        
        UploadPostModel.shared.postObject = post
    }
    
    func addPreviewView() {
        /// add initial preview view and buttons

        let post = UploadPostModel.shared.postObject!
        
        /// camera aspect is also the max aspect for any image'
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.85
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let maxY = minY + cameraHeight
                
        previewBackground = UIView {
            $0.backgroundColor = UIColor(named: "SpotBlack")
            $0.layer.cornerRadius = 15
            view.addSubview($0)
        }
        previewBackground.snp.makeConstraints {
            $0.leading.trailing.top.bottom.equalToSuperview()
        }
                
        currentImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex!)
        view.addSubview(currentImage)
        currentImage.makeConstraints()
        currentImage.setCurrentImage()

        if post.frameIndexes!.count > 1 {
            nextImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex! + 1)
            view.addSubview(nextImage)
            nextImage.makeConstraints()
            nextImage.setCurrentImage()
            
            previousImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex! - 1)
            view.addSubview(previousImage)
            previousImage.makeConstraints()
            previousImage.setCurrentImage()
            
            let pan = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
            view.addGestureRecognizer(pan)
            addDotView()
        }
                                
        /// add cancel button
        backButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
            $0.setImage(UIImage(named: "BackArrow"), for: .normal)
            $0.addTarget(self, action: #selector(backTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        backButton.snp.makeConstraints {
            $0.leading.equalTo(5.5)
            $0.top.equalTo(previewBackground.snp.top).offset(55)
            $0.width.equalTo(48.6)
            $0.height.equalTo(38.6)
        }
                
        /// add share to and drafts
        chooseMapButton = ChooseMapButton {
            $0.addTarget(self, action: #selector(chooseMapTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        chooseMapButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(12)
            $0.top.equalTo(maxY + 6)
            $0.width.equalTo(162)
            $0.height.equalTo(40)
        }
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        panGesture.isEnabled = false
        view.addGestureRecognizer(panGesture)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(captionTap(_:)))
        view.addGestureRecognizer(tap)
    }
        
    func addDotView() {
        let imageCount = UploadPostModel.shared.postObject.frameIndexes!.count
        let dotWidth = (14 * imageCount) + (10 * (imageCount - 1))
        dotView = UIView {
            $0.backgroundColor = nil
            view.addSubview($0)
        }
        dotView.snp.makeConstraints {
            $0.top.equalTo(previewBackground.snp.top).offset(72)
            $0.height.equalTo(14)
            $0.width.equalTo(dotWidth)
            $0.centerX.equalToSuperview()
        }
        addDots()
    }
    
    func addDots() {
        if dotView != nil { for sub in dotView.subviews { sub.removeFromSuperview() } }
        for i in 0...UploadPostModel.shared.postObject.frameIndexes!.count - 1 {
            let dot = UIView {
                $0.backgroundColor = .white
                $0.alpha = i == UploadPostModel.shared.postObject.selectedImageIndex! ? 1.0 : 0.35
                $0.layer.cornerRadius = 7
                dotView.addSubview($0)
            }
            let leading = i * 24
            dot.snp.makeConstraints {
                $0.leading.equalTo(leading)
                $0.top.equalToSuperview()
                $0.width.height.equalTo(14)
            }
        }
    }

    func addPostDetail() {
        let firstImageAspect = (UploadPostModel.shared.postObject.postImage.first ?? UIImage()).size.height / (UploadPostModel.shared.postObject.postImage.first ?? UIImage()).size.width
        postDetailView = PostDetailView {
            view.addSubview($0)
        }
        postDetailView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(300)
            if firstImageAspect > 1.1 {
                snapBottomConstraintToImage = true
                $0.bottom.equalTo(currentImage.snp.bottom)
            } else {
                $0.bottom.equalTo(chooseMapButton.snp.top).offset(-25)
            }
        }
        
        textView = UITextView {
            $0.delegate = self
            $0.font = UIFont(name: "SFCompactText-Regular", size: 19)
            $0.backgroundColor = .clear
            $0.textColor = .white
            $0.alpha = 0.6
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.text = textViewPlaceholder
            $0.returnKeyType = .done
            $0.textContainerInset = UIEdgeInsets(top: 14, left: 19, bottom: 14, right: 19)
            $0.isScrollEnabled = false
            $0.textContainer.maximumNumberOfLines = 6
            $0.textContainer.lineBreakMode = .byTruncatingHead
            $0.isUserInteractionEnabled = false
            postDetailView.addSubview($0)
        }
        textView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.lessThanOrEqualToSuperview().inset(36)
            $0.bottom.equalToSuperview()
        }
        
        spotNameButton = SpotNameButton(frame: .zero)
        spotNameButton.addTarget(self, action: #selector(spotTap(_:)), for: .touchUpInside)
        spotNameButton.translatesAutoresizingMaskIntoConstraints = false
        postDetailView.addSubview(spotNameButton)
        spotNameButton.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.bottom.equalTo(textView.snp.top)
            $0.height.equalTo(36)
            $0.trailing.lessThanOrEqualToSuperview().inset(16)
        }
    }
        
    @objc func imageSwipe(_ gesture: UIPanGestureRecognizer) {
        let direction = gesture.velocity(in: view)
        let translation = gesture.translation(in: view)
        let composite = translation.x + direction.x/4
        let selectedIndex = UploadPostModel.shared.postObject.selectedImageIndex!
        let imageCount = UploadPostModel.shared.postObject.frameIndexes!.count
        
        switch gesture.state {
        case .changed:
            currentImage.snp.updateConstraints({$0.leading.trailing.equalToSuperview().offset(translation.x)})
            nextImage.snp.updateConstraints({$0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width + translation.x)})
            previousImage.snp.updateConstraints({$0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width + translation.x)})
            
        case .ended:
            if (composite < -UIScreen.main.bounds.width/2) && (selectedIndex < imageCount - 1) {
                animateNext()
            } else if (composite > UIScreen.main.bounds.width/2) && (selectedIndex > 0) {
                animatePrevious()
            } else {
                resetFrame()
            }
            
        default: return
        }

    }
    
    func animateNext() {
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) }
        nextImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        }) { [weak self] _ in
            guard let self = self else { return }
            /// reset image indexe
            UploadPostModel.shared.postObject!.selectedImageIndex! += 1
            self.setImages()
        }
    }
    
    func animatePrevious() {
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        previousImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        }) { [weak self] _ in
            guard let self = self else { return }
            /// reset image indexes
            UploadPostModel.shared.postObject!.selectedImageIndex! -= 1
            self.setImages()
        }
    }
    
    func resetFrame() {
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }
        previousImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) }
        nextImage.snp.updateConstraints {
            $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width )
        }
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    func setImages() {
        let selectedIndex = UploadPostModel.shared.postObject!.selectedImageIndex!
        currentImage.index = selectedIndex
        currentImage.makeConstraints()
        currentImage.setCurrentImage()
        
        previousImage.index = selectedIndex - 1
        previousImage.makeConstraints()
        previousImage.setCurrentImage()
        
        nextImage.index = selectedIndex + 1
        nextImage.makeConstraints()
        nextImage.setCurrentImage()
        addDots()
    }
    
    @objc func backTap(_ sender: UIButton) {
        if cameraObject != nil { UploadPostModel.shared.selectedObjects.removeAll(where: {$0.fromCamera})} /// remove old captured image
        
        let controllers = navigationController?.viewControllers
        if let camera = controllers?[safe: (controllers?.count ?? 0) - 3] as? AVCameraController {
            /// set spotObject to nil if we're not posting directly to the spot from the spot page
            if camera.spotObject == nil { UploadPostModel.shared.setSpotValues(spot: nil) }
            /// reset postObject
            camera.setUpPost()
        }
        
        navigationController?.popViewController(animated: false)
    }
    
    @objc func spotTap(_ sender: UIButton) {
        textView.resignFirstResponder()
        launchPicker()
    }
        
    @objc func captionTap(_ sender: UITapGestureRecognizer) {
        shouldRepositionTextView = true
        textView.becomeFirstResponder()
    }
    
    @objc func chooseMapTap(_ sender: UIButton) {
        UploadPostModel.shared.postObject.caption = textView.text ?? ""
        
        if let vc = storyboard?.instantiateViewController(withIdentifier: "ShareTo") as? ShareToController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func launchPicker() {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "ChooseSpot") as? ChooseSpotController {
            vc.delegate = self
            DispatchQueue.main.async { self.present(vc, animated: true) }
        }
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        if !shouldRepositionTextView { return }
        postDetailView.bottomMask.alpha = 0.0
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.postDetailView.bottomMask.alpha = 1.0
            self.postDetailView.snp.removeConstraints()
            self.postDetailView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height)
                $0.height.equalTo(300)
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        shouldRepositionTextView = false
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.postDetailView.snp.removeConstraints()
            self.postDetailView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(300)
                if self.snapBottomConstraintToImage { $0.bottom.equalTo(self.currentImage.snp.bottom) } else { $0.bottom.equalTo(self.chooseMapButton.snp.top).offset(-25) }
            }
        }
    }
}

extension ImagePreviewController: ChooseSpotDelegate {
    func finishPassing(spot: MapSpot) {
        UploadPostModel.shared.setSpotValues(spot: spot)
        spotNameButton.spotName = spot.spotName
    }
    func cancelSpotSelection() {
        UploadPostModel.shared.setSpotValues(spot: nil)
        spotNameButton.spotName = nil
    }
}

extension ImagePreviewController: UITextViewDelegate, UIGestureRecognizerDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        panGesture.isEnabled = true
        if textView.text == textViewPlaceholder { textView.text = ""; textView.alpha = 1.0 }
        textView.isUserInteractionEnabled = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        panGesture.isEnabled = false
        if textView.text == "" { textView.text = textViewPlaceholder; textView.alpha = 0.6 }
        textView.isUserInteractionEnabled = false
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        /// return on done button tap
        if text == "\n" { textView.endEditing(true); return false }
        
        let maxLines: CGFloat = 6
        let maxHeight: CGFloat = textView.font!.lineHeight * maxLines + 30 /// lineheight * # lines  + textContainer insets
        
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)

        let val = getCaptionHeight(text: updatedText) <= maxHeight
        return val
    }
    
    
    /*
    func textViewDidChange(_ textView: UITextView) {
        
        let maxLines: CGFloat = 6
        let maxHeight: CGFloat = textView.font!.lineHeight * maxLines + 28
        
        let size = textView.sizeThatFits(CGSize(width: UIScreen.main.bounds.width, height: maxHeight))
        if size.height != textView.frame.height {
            let diff = size.height - textView.frame.height
            /// expand textview and slide it up to move away from the keyboard
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY - diff, width: textView.frame.width, height: textView.frame.height + diff)
        }
        ///add tag table if @ used
        let cursor = textView.getCursorPosition()
     //   addRemoveTagTable(text: textView.text ?? "", cursorPosition: cursor, tableParent: .comments)
    } */
    
    func getCaptionHeight(text: String) -> CGFloat {
                
        let temp = UITextView(frame: textView.frame)
        temp.text = text
        temp.font = UIFont(name: "SFCompactText-Regular", size: 19)
        temp.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        temp.isScrollEnabled = false
        temp.textContainer.maximumNumberOfLines = 6
        
        let size = temp.sizeThatFits(CGSize(width: temp.bounds.width, height: UIScreen.main.bounds.height))
        return max(51, size.height)
    }
    
    @objc func pan(_ sender: UIPanGestureRecognizer) {
        
        if !self.textView.isFirstResponder { return }
        
        let direction = sender.velocity(in: view)
        
        if abs(direction.y) > 100 {
            textView.resignFirstResponder()
            panGesture.isEnabled = false
        }
    }
}

class AddedUsersView: UIView {
    
    var userIcon: UIImageView!
    var countLabel: UILabel!
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        
        /// remove tapGesture if previously added
        if let tap = gestureRecognizers?.first(where: {$0.isKind(of: UITapGestureRecognizer.self)}) { removeGestureRecognizer(tap) }
        
        if userIcon != nil { userIcon.image = UIImage() }
        userIcon = UIImageView {
            $0.frame = CGRect(x: 13, y: 11, width: 20.4, height: 19.35)
            $0.image = UIImage(named: "SingleUserIcon")
            addSubview($0)
        }
        
        if countLabel != nil { countLabel.text = "" }
        countLabel = UILabel {
            $0.frame = CGRect(x: userIcon.frame.maxX + 5, y: userIcon.frame.minY + 2, width: 30, height: 16)
            $0.text = "\(UploadPostModel.shared.postObject.addedUsers!.count)"
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Bold", size: 17.5)
            addSubview($0)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SpotNameButton: UIButton {
    var spotIcon: UIImageView!
    var nameLabel: UILabel!
    var cancelButton: UIButton!
    
    var spotName: String? {
        didSet {
            nameLabel.text = spotName ?? "Add spot"
            if spotName != nil {
                cancelButton.isHidden = false
                cancelButton.snp.updateConstraints { $0.height.width.equalTo(32) }
            //    nameLabel.snp.updateConstraints { $0.tra }
            } else {
                cancelButton.isHidden = true
                cancelButton.snp.updateConstraints { $0.height.width.equalTo(5) }
            }
        }
    }

    override init(frame: CGRect) {
        
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        spotIcon = UIImageView {
            $0.image = UIImage(named: "AddSpotIcon")
            addSubview($0)
        }
        spotIcon.snp.makeConstraints {
            $0.leading.equalTo(8)
            $0.height.equalTo(21)
            $0.width.equalTo(17.6)
            $0.centerY.equalToSuperview()
        }
        
        cancelButton = UIButton {
            $0.setImage(UIImage(named: "FeedExit"), for: .normal)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.isHidden = true
            addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(6)
            $0.height.width.equalTo(5)
            $0.centerY.equalToSuperview()
        }
        
        nameLabel = UILabel {
            $0.text = UploadPostModel.shared.spotObject?.spotName ?? "Add spot"
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 15)
            $0.lineBreakMode = .byTruncatingTail
            $0.sizeToFit()
            addSubview($0)
        }
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(spotIcon.snp.trailing).offset(6.5)
            $0.trailing.equalTo(cancelButton.snp.leading)
            $0.centerY.equalToSuperview()
        }
        
        /// remove tapGesture if previously added
        if let tap = gestureRecognizers?.first(where: {$0.isKind(of: UITapGestureRecognizer.self)}) { removeGestureRecognizer(tap) }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        if let previewVC = viewContainingController() as? ImagePreviewController {
            previewVC.cancelSpotSelection()
        }
    }
}

class PostImagePreview: PostImageView {
    
    var index: Int!
    
    convenience init(frame: CGRect, index: Int) {
        self.init(frame: frame)
        self.index = index
        
        contentMode = .scaleAspectFill
        clipsToBounds = true
        isUserInteractionEnabled = true
        layer.cornerRadius = 15
        backgroundColor = nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeConstraints() {
        
        snp.removeConstraints()
        
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.85
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let post = UploadPostModel.shared.postObject!
        let currentImage = post.postImage[safe: post.frameIndexes?[safe: index] ?? -1] ?? UIImage(color: .black, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width))!
        let currentAspect = (currentImage.size.height) / (currentImage.size.width)
        let currentHeight = getImageHeight(aspectRatio: currentAspect, maxAspect: cameraAspect)
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let maxY = minY + cameraHeight
        
        let imageY: CGFloat = currentAspect + 0.02 >= cameraAspect ? minY : (minY + maxY - currentHeight)/2 + 15
        
        snp.makeConstraints {
            $0.height.equalTo(currentHeight)
            $0.top.equalTo(imageY)
            if index == post.selectedImageIndex { $0.leading.trailing.equalToSuperview() }
            else if index < post.selectedImageIndex ?? 0 { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) }
            else if index > post.selectedImageIndex ?? 0 { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        }
        
        for sub in subviews { sub.removeFromSuperview() } /// remove any old masks
        if currentAspect > 1.6 { addTop() }
    }
    
    func setCurrentImage() {
        let post = UploadPostModel.shared.postObject!
        let images = post.postImage
        let frameIndexes = post.frameIndexes ?? []
        
        let still = images[safe: frameIndexes[safe: index] ?? -1] ?? UIImage.init(color: UIColor(named: "SpotBlack")!, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width))!
        image = still
        stillImage = still
        
        let animationImages = getGifImages(selectedImages: images, frameIndexes: post.frameIndexes!, imageIndex: post.selectedImageIndex!)
        self.animationImages = animationImages
        animationIndex = 0

        if !animationImages.isEmpty && !activeAnimation {
            animateGIF(directionUp: true, counter: animationIndex)
        }
    }
    
    func getGifImages(selectedImages: [UIImage], frameIndexes: [Int], imageIndex: Int) -> [UIImage] {
        /// return empty set of images if there's only one image for this frame index (still image), return all images at this frame index if there's more than 1 image
        guard let selectedFrame = frameIndexes[safe: imageIndex] else { return [] }
        
        if frameIndexes.count == 1 {
            return selectedImages.count > 1 ? selectedImages : []
        } else if frameIndexes.count - 1 == imageIndex {
            return selectedImages[selectedFrame] != selectedImages.last ? selectedImages.suffix(selectedImages.count - 1 - selectedFrame) : []
        } else {
            let frame1 = frameIndexes[imageIndex + 1]
            return frame1 - selectedFrame > 1 ? Array(selectedImages[selectedFrame...frame1 - 1]) : []
        }
    }
    
    func addTop() {
        let topMask = UIView {
            addSubview($0)
        }
        topMask.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(100)
        }
        let _ = CAGradientLayer {
            $0.frame = topMask.bounds
            $0.colors = [
              UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
              UIColor(red: 0, green: 0, blue: 0, alpha: 0.45).cgColor
            ]
            $0.startPoint = CGPoint(x: 0.5, y: 1.0)
            $0.endPoint = CGPoint(x: 0.5, y: 0.0)
            $0.locations = [0, 1]
            topMask.layer.addSublayer($0)
        }
    }
    
    func getImageHeight(aspectRatio: CGFloat, maxAspect: CGFloat) -> CGFloat {
      
        var imageAspect =  min(aspectRatio, maxAspect)
        if imageAspect > 1.1 && imageAspect < 1.6 { imageAspect = 1.6 } /// stretch iPhone vertical
        if imageAspect > 1.6 { imageAspect = maxAspect } /// round to max aspect
        
        let imageHeight = UIScreen.main.bounds.width * imageAspect
        return imageHeight
    }
}

class PostDetailView: UIView {
    var bottomMask: UIView!
    override func layoutSubviews() {
        if bottomMask != nil { return }
        bottomMask = UIView {
            insertSubview($0, at: 0)
        }
        bottomMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        let _ = CAGradientLayer {
            $0.frame = bounds
            $0.colors = [
              UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
              UIColor(red: 0, green: 0, blue: 0, alpha: 0.07).cgColor,
              UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.45).cgColor
            ]
            $0.startPoint = CGPoint(x: 0.5, y: 0.0)
            $0.endPoint = CGPoint(x: 0.5, y: 1.0)
            $0.locations = [0, 0.35, 1]
            bottomMask.layer.addSublayer($0)
        }
    }
}

class ChooseMapButton: UIButton {
    var chooseLabel: UILabel!
    var nextArrow: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 9
        backgroundColor = UIColor(named: "SpotGreen")
        
        chooseLabel = UILabel {
            $0.text = "Choose a map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 15)
            addSubview($0)
        }
        chooseLabel.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.centerY.equalToSuperview()
        }
        
        nextArrow = UIImageView {
            $0.image = UIImage(named: "NextArrow")
            addSubview($0)
        }
        nextArrow.snp.makeConstraints {
            $0.leading.equalTo(chooseLabel.snp.trailing).offset(8)
            $0.height.equalTo(15.3)
            $0.width.equalTo(16.8)
            $0.centerY.equalToSuperview().offset(1)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
