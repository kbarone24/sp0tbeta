//
//  SpotPickerDelegates.swift
//  Spot
//
//  Created by Kenny Barone on 8/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import PhotosUI
import Mixpanel

extension SpotController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !datasource.snapshot().sectionIdentifiers.isEmpty else { return UIView() }
        let section = datasource.snapshot().sectionIdentifiers[section]
        switch section {
        case .main(spot: let spot, let activeSortMethod):
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: SpotOverviewHeader.reuseID) as? SpotOverviewHeader
            header?.configure(spot: spot, sort: activeSortMethod)
            header?.sortButton.addTarget(self, action: #selector(sortTap), for: .touchUpInside)
            return header
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 2) && !isRefreshingPagination, !disablePagination {
            isRefreshingPagination = true
            refresh.send(true)
            self.postListenerForced.send((false, (nil, nil)))
            sort.send(viewModel.activeSortMethod)
        }

        // set seen for post
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        switch item {
        case .item(let post):
            viewModel.updatePostIndex(post: post)
        }
    }

    @objc func sortTap() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "New", style: .default) { [weak self] _ in
                // sort by new
                guard let self, self.viewModel.activeSortMethod == .Top else { return }
                self.viewModel.activeSortMethod = .New
                self.refresh.send(false)

                self.refresh.send(true)
                self.postListenerForced.send((false, (nil, nil)))
                self.sort.send(.New)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Top", style: .default) { [weak self] _ in
                guard let self, self.viewModel.activeSortMethod == .New else { return }
                self.viewModel.activeSortMethod = .Top
                self.refresh.send(false)

                self.viewModel.lastRecentDocument = nil
                self.refresh.send(true)
                self.postListenerForced.send((false, (nil, nil)))
                self.sort.send(.Top)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in }
        )

        present(alert, animated: true)
    }
}

extension SpotController: PostCellDelegate {
    func likePost(post: MapPost) {
        viewModel.likePost(post: post)
        refresh.send(false)
    }

    func unlikePost(post: MapPost) {
        viewModel.unlikePost(post: post)
        refresh.send(false)
    }

    func dislikePost(post: MapPost) {
        viewModel.dislikePost(post: post)
        refresh.send(false)
    }

    func undislikePost(post: MapPost) {
        viewModel.undislikePost(post: post)
        refresh.send(false)
    }

    func moreButtonTap(post: MapPost) {
        addActionSheet(post: post)
    }

    func viewMoreTap(parentPostID: String) {
        if let post = viewModel.presentedPosts.first(where: { $0.id == parentPostID }) {
            refresh.send(true)
            postListenerForced.send((true, (post, post.lastCommentDocument)))
            sort.send(viewModel.activeSortMethod)
        }
    }

    func replyTap(parentPostID: String, replyUsername: String, parentPosterID: String) {
        openCreate(parentPostID: parentPostID, replyUsername: replyUsername, parentPosterID: parentPosterID, imageObject: nil, videoObject: nil)
    }
}

extension SpotController: SpotTextFieldFooterDelegate {
    func userTap() {
        print("user tap")
    }

    func textAreaTap() {
        openCreate(parentPostID: nil, replyUsername: nil, parentPosterID: nil, imageObject: nil, videoObject: nil)
    }

    func cameraTap() {
        addActionSheet()
    }

    func addActionSheet() {
        // add camera here, return to SpotController on cancel, push Create with selected content on confirm
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                guard let self else { return }
                let picker = UIImagePickerController()
                picker.allowsEditing = false
                picker.mediaTypes = ["public.image", "public.movie"]
                picker.sourceType = .camera
                picker.videoMaximumDuration = 15
                picker.videoQuality = .typeHigh
                picker.delegate = self
                self.cameraPicker = picker
                self.present(picker, animated: true)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Gallery", style: .default) { [weak self] _ in
                guard let self else { return }
                var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
                config.filter = .any(of: [.images, .videos])
                config.selectionLimit = 1
                config.preferredAssetRepresentationMode = .current
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.galleryPicker = picker
                self.present(picker, animated: true)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in
            }
        )
        present(alert, animated: true)
    }

    func openCreate(parentPostID: String?, replyUsername: String?, parentPosterID: String?, imageObject: ImageObject?, videoObject: VideoObject?) {
        let vc = CreatePostController(spot: viewModel.cachedSpot, parentPostID: parentPostID, replyUsername: replyUsername, parentPosterID: parentPosterID, imageObject: imageObject, videoObject: videoObject)
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
}

extension SpotController: SpotMoveCloserFooterDelegate {
    func refreshLocation() {
        addFooter()
    }
}

extension SpotController: CreatePostDelegate {
    func finishUpload(post: MapPost) {
        viewModel.addNewPost(post: post)
        self.refresh.send(false)

        if let index = viewModel.getSelectedIndexFor(post: post) {
            DispatchQueue.main.async {
                self.tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .top, animated: false)
            }
        }
    }
}


extension SpotController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: false)

        if let image = info[.originalImage] as? UIImage {
            let imageObject = ImageObject(image: image, fromCamera: true)
            openCreate(parentPostID: nil, replyUsername: nil, parentPosterID: nil, imageObject: imageObject, videoObject: nil)

        } else if let url = info[.mediaURL] as? URL {
            let videoObject = VideoObject(url: url, fromCamera: true)
            openCreate(parentPostID: nil, replyUsername: nil, parentPosterID: nil, imageObject: nil, videoObject: videoObject)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first else {
            picker.dismiss(animated: true)
            return
        }

        let itemProvider = result.itemProvider
        guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first,
              let utType = UTType(typeIdentifier)
        else { return }

        if utType.conforms(to: .movie) {
            let identifiers = results.compactMap(\.assetIdentifier)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            if let asset = fetchResult.firstObject {
                DispatchQueue.main.async {
                    self.launchVideoEditor(asset: asset)
                    picker.dismiss(animated: true)
                }
            }

        } else {
            itemProvider.getPhoto { [weak self] image in
                guard let self = self else { return }
                if let image {
                    DispatchQueue.main.async {
                        self.launchStillImagePreview(imageObject: ImageObject(image: image, fromCamera: false))
                        picker.dismiss(animated: true)
                    }
                }
            }
        }

    }

    func launchStillImagePreview(imageObject: ImageObject) {
        let vc = StillImagePreviewView(imageObject: imageObject)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: false)
    }

    func launchVideoEditor(asset: PHAsset) {
        let vc = VideoEditorController(videoAsset: asset)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: false)
    }
}

extension SpotController: VideoEditorDelegate, StillImagePreviewDelegate {
    func finishPassing(imageObject: ImageObject) {
        openCreate(parentPostID: nil, replyUsername: nil, parentPosterID: nil, imageObject: imageObject, videoObject: nil)
    }

    func finishPassing(videoObject: VideoObject) {
        openCreate(parentPostID: nil, replyUsername: nil, parentPosterID: nil, imageObject: nil, videoObject: videoObject)
    }
}
