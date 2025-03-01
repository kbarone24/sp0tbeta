//
//  CoreDataService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/13/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import CoreData
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Mixpanel

/*
protocol CoreDataServiceProtocol {
    func fetchFailedImageUploads(completion: @escaping ((PostDraft?, UIImage?) -> Void))
    func deletePostDraft(timestampID: Int64)
    func uploadPostDraft(postDraft: PostDraft?, parentView: UIView?, progressFill: UIView?, completion: @escaping ((Bool) -> Void))
}

final class CoreDataService: CoreDataServiceProtocol {
    
    private enum Entity {
        case post
        
        var name: String {
            switch self {
            case .post: return "PostDraft"
            }
        }
    }
    
    func deletePostDraft(timestampID: Int64) {
        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            Mixpanel.mainInstance().track(event: "CameraDeletePostDraft", properties: nil)
            
            let managedContext =
            appDelegate.persistentContainer.viewContext
            let fetchRequest =
            NSFetchRequest<PostDraft>(entityName: Entity.post.name)
            fetchRequest.predicate = NSPredicate(format: "timestamp == %d", timestampID)
            
            guard let drafts = try? managedContext.fetch(fetchRequest) else {
                return
            }
            
            for draft in drafts {
                managedContext.delete(draft)
            }
            try? managedContext.save()
        }
    }
    
    func fetchFailedImageUploads(completion: @escaping ((PostDraft?, UIImage?) -> Void)) {
        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate,
              let uid = Auth.auth().currentUser?.uid
        else {
            completion(nil, nil)
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            let managedContext =
            appDelegate.persistentContainer.viewContext
            let postsRequest =
            NSFetchRequest<PostDraft>(entityName: "PostDraft")
            
            postsRequest.relationshipKeyPathsForPrefetching = ["images"]
            postsRequest.returnsObjectsAsFaults = false
            postsRequest.predicate = NSPredicate(format: "uid == %@", uid)
            let timeSort = NSSortDescriptor(key: "timestamp", ascending: false)
            postsRequest.sortDescriptors = [timeSort]
            
            guard let self,
                  let failedPosts = try? managedContext.fetch(postsRequest),
                  let post = failedPosts.first else {
                completion(nil, nil)
                return
            }
            
            // test for corrupted draft or old draft (pre 1.0)
            let timestampID = post.timestamp
            
            if post.images == nil {
                self.deletePostDraft(timestampID: timestampID)
            }
            
            guard let images = post.images as? Set<ImageModel> else {
                return
            }
            
            let firstImageData = images.first?.imageData
            if firstImageData == nil || post.addedUsers == nil {
                self.deletePostDraft(timestampID: timestampID)
                
            } else {
                let postImage = UIImage(data: firstImageData! as Data) ?? UIImage()
                completion(post, postImage)
            }
        }
    }
    
    func uploadPostDraft(postDraft: PostDraft?, parentView: UIView?, progressFill: UIView?, completion: @escaping ((Bool) -> Void)) {
        guard let postDraft = postDraft,
              let model = postDraft.images as? Set<ImageModel>,
              !model.isEmpty,
              let spotService = try? ServiceContainer.shared.service(for: \.spotService),
              let postService = try? ServiceContainer.shared.service(for: \.postService),
              let imageVideoService = try? ServiceContainer.shared.service(for: \.imageVideoService),
              let userService = try? ServiceContainer.shared.service(for: \.userService),
              let uid = Auth.auth().currentUser?.uid
        else {
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            
            Task {
                let mod = model.sorted(by: { $0.position < $1.position })
                var uploadImages: [UIImage?] = []
                
                for i in 0..<mod.count {
                    let im = mod[i]
                    if let imageData = im.imageData {
                        uploadImages.append(UIImage(data: imageData))
                    } else {
                        uploadImages.append(UIImage())
                    }
                }
                
                let imagesToBeUploaded = uploadImages.compactMap { $0 }
                let actualTimestamp = Timestamp(seconds: postDraft.timestamp, nanoseconds: 0)
                var aspectRatios: [CGFloat] = []
                
                postDraft.aspectRatios?
                    .compactMap { $0 }
                    .forEach {
                        aspectRatios.append(CGFloat($0))
                    }

                let postLocation = ["lat": postDraft.postLat, "long": postDraft.postLong]
                var post = MapPost(
                    id: UUID().uuidString,
                    posterID: uid,
                    postDraft: postDraft,
                    mapInfo: nil,
                    actualTimestamp: actualTimestamp,
                    uploadImages: imagesToBeUploaded,
                    imageURLs: [],
                    aspectRatios: aspectRatios,
                    likers: []
                )

                var spot = MapSpot(post: post, postDraft: postDraft, imageURL: "")
                
         //       UploadPostModel.shared.postType = postDraft.newSpot ? .newSpot : postDraft.postToPOI ? .postToPOI : spot.id != "" ? .postToSpot : .none
                var mapToUpload: CustomMap
                
                if let mapID = post.mapID, mapID != "", let map = try? await mapService.getMap(mapID: mapID) {
                    mapToUpload = map
                } else {
                    mapToUpload = CustomMap(
                        founderID: "",
                        imageURL: "",
                        likers: [],
                        mapName: "",
                        memberIDs: [],
                        posterIDs: [],
                        posterUsernames: [],
                        postIDs: [],
                        postImageURLs: [],
                        secret: false,
                        spotIDs: []
                    )
                }
                let dispatch = DispatchGroup()
                // Upload video if available
                if let data = postDraft.videoData {
                    dispatch.enter()
                    imageVideoService.uploadVideo(data: data, success: { videoURL in
                        guard videoURL != "" else {
                            Mixpanel.mainInstance().track(event: "FailedDraftUpload")
                            completion(false)
                            return
                        }
                        post.videoURL = videoURL
                        dispatch.leave()
                    }, failure: { _ in
                        Mixpanel.mainInstance().track(event: "FailedDraftUpload")
                        completion(false)
                        return
                    })
                }

                // Upload post
                dispatch.enter()
                await imageVideoService.uploadImages(
                    images: post.postImage,
                    parentView: parentView,
                    progressFill: progressFill,
                    fullWidth: UIScreen.main.bounds.width - 100
                ) { imageURLs, failed in
                    
                    if imageURLs.isEmpty && failed {
                        Mixpanel.mainInstance().track(event: "FailedDraftUpload")
                        completion(false)
                        return
                    }
                    
                    post.imageURLs = imageURLs
                    post.timestamp = Timestamp(date: Date())
                    dispatch.leave()
                }

                dispatch.notify(queue: .global()) {
                    let newMap = post.mapID ?? "" != "" && mapToUpload.id ?? "" == ""
                    let defaultMapID = UUID().uuidString
                    let defaultPostID = UUID().uuidString
                    
                    if newMap {
                        mapToUpload = CustomMap(
                            id: post.mapID ?? defaultMapID,
                            founderID: uid,
                            imageURL: post.imageURLs[0],
                            likers: [uid],
                            mapName: post.mapName ?? "",
                            memberIDs: [uid],
                            posterDictionary: [(post.id ?? defaultPostID): [uid]],
                            posterIDs: [uid],
                            posterUsernames: [UserDataModel.shared.userInfo.username],
                            postIDs: [post.id ?? defaultPostID],
                            postImageURLs: [post.imageURLs.first ?? ""],
                            postLocations: [
                                [
                                    "lat": post.postLat ?? 0,
                                    "long": post.postLong ?? 0
                                ]
                            ], postSpotIDs: [post.spotID ?? ""],
                            postTimestamps: [post.timestamp],
                            secret: postDraft.mapSecret,
                            spotIDs: [],
                            spotNames: [],
                            spotLocations: [],
                            memberProfiles: [UserDataModel.shared.userInfo],
                            coverImage: uploadImages.first ?? UIImage()
                        )
                        
                        let lowercaseName = (post.mapName ?? "").lowercased()
                        mapToUpload.lowercaseName = lowercaseName
                        mapToUpload.searchKeywords = lowercaseName.getKeywordArray()
                        
                        /// add added users
                        if let addedUsers = post.taggedUserIDs, !addedUsers.isEmpty { mapToUpload.memberIDs.append(contentsOf: addedUsers)
                            mapToUpload.likers.append(contentsOf: addedUsers)
                            mapToUpload.memberProfiles?.append(contentsOf: post.addedUserProfiles ?? [])
                            mapToUpload.posterDictionary[post.id ?? ""]?.append(contentsOf: addedUsers)
                        }
                        
                        if let spotID = spot.id {
                            mapToUpload.postSpotIDs[0] = spotID
                            mapToUpload.spotIDs.append(spotID)
                            mapToUpload.spotNames.append(spot.spotName)
                            mapToUpload.spotPOICategories.append(spot.poiCategory ?? "")
                            mapToUpload.spotLocations.append(["lat": spot.spotLat, "long": spot.spotLong])
                        }
                    }
                    
                    if spot.id != "" {
                        spot.imageURL = post.imageURLs.first ?? ""
                        spotService.uploadSpot(post: post, spot: spot)
                    }
                    
                    if mapToUpload.id ?? "" != "" {
                        if mapToUpload.imageURL == "" {
                            mapToUpload.imageURL = post.imageURLs.first ?? ""
                        }
                        
                        mapService.uploadMap(map: mapToUpload, newMap: newMap, post: post, spot: spot)
                    }

                    /*
                    postService.uploadPost(post: post, map: mapToUpload, spot: spot, newMap: newMap)
                    
                    let visitorList = spot.visitorList
                    userService.setUserValues(poster: uid, post: post, spotID: spot.id ?? "", visitorList: visitorList, mapID: mapToUpload.id ?? "")
                    */
                    completion(true)
                }
            }
        }
    }
}

*/
