import Foundation
import UIKit
import CoreLocation
import Combine
import SwiftUI

@MainActor
class PostUploadManager: ObservableObject {
    static let shared = PostUploadManager()
    
    @Published var uploadingPost: SocialWorkoutPost?
    @Published var isUploading = false
    @Published var uploadFailed = false
    
    private var pendingUploadTask: Task<Void, Never>?
    
    struct UploadContext {
        let post: WorkoutPost
        let routeImage: UIImage?
        let userImage: UIImage?
        let earnedPoints: Int
        let isLivePhoto: Bool
        let activityType: String
        let exercisesData: [GymExercisePost]?
        let userId: String?
        let userName: String?
        let userAvatarUrl: String?
        let hasPB: Bool
        let pbExerciseName: String
        let pbValue: String
        let stravaConnected: Bool
        let stravaTitle: String
        let stravaDescription: String
        let stravaDuration: Int
        let stravaDistance: Double
        let stravaRouteCoordinates: [CLLocationCoordinate2D]
        let isPublic: Bool
    }
    
    func startUpload(context: UploadContext) {
        let placeholderPost = SocialWorkoutPost(
            from: context.post,
            userName: context.userName,
            userAvatarUrl: context.userAvatarUrl,
            userIsPro: RevenueCatManager.shared.isProMember
        )
        
        uploadingPost = placeholderPost
        isUploading = true
        uploadFailed = false
        
        pendingUploadTask = Task {
            do {
                try await WorkoutService.shared.saveWorkoutPost(
                    context.post,
                    routeImage: context.routeImage,
                    userImage: context.userImage,
                    earnedPoints: context.earnedPoints,
                    isLivePhoto: context.isLivePhoto
                )
                
                if context.earnedPoints > 0 && context.activityType == "Gympass" {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let key = "gymPoints_\(formatter.string(from: Date()))"
                    let existing = UserDefaults.standard.integer(forKey: key)
                    UserDefaults.standard.set(existing + context.earnedPoints, forKey: key)
                }
                
                if let userId = context.userId {
                    if let updatedProfile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                        await MainActor.run {
                            AuthViewModel.shared.currentUser = updatedProfile
                        }
                    }
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("WorkoutSaved"), object: nil)
                
                if context.activityType == "Gympass", let exercisesData = context.exercisesData {
                    GymLocationManager.shared.gymSessionSaved()
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("GymWorkoutCompleted"),
                        object: nil,
                        userInfo: ["exercises": exercisesData]
                    )
                    
                    if let userId = context.userId {
                        let xpGains = MuscleProgressionService.shared.processGymSession(
                            userId: userId,
                            exercises: exercisesData
                        )
                        for gain in xpGains {
                            print("💪 Strength XP: +\(gain.xpGained) for \(gain.muscleGroups.joined(separator: ", "))")
                        }
                    }
                }
                
                if context.hasPB, let userId = context.userId {
                    await PushNotificationService.shared.notifyFollowersAboutPB(
                        userId: userId,
                        userName: context.userName ?? "En användare",
                        userAvatar: context.userAvatarUrl,
                        exerciseName: context.pbExerciseName,
                        pbValue: context.pbValue,
                        postId: context.post.id
                    )
                }
                
                if context.stravaConnected {
                    let _ = await StravaService.shared.uploadActivity(
                        title: context.stravaTitle,
                        description: context.stravaDescription,
                        activityType: context.activityType,
                        startDate: Date().addingTimeInterval(TimeInterval(-context.stravaDuration)),
                        duration: context.stravaDuration,
                        distance: context.stravaDistance > 0 ? context.stravaDistance : nil,
                        routeCoordinates: context.stravaRouteCoordinates.isEmpty ? nil : context.stravaRouteCoordinates
                    )
                }
                
                let completedPost = SocialWorkoutPost(
                    from: context.post,
                    userName: context.userName,
                    userAvatarUrl: context.userAvatarUrl,
                    userIsPro: RevenueCatManager.shared.isProMember
                )
                
                await MainActor.run {
                    if context.isPublic {
                        SocialViewModel.shared.insertPostAtTop(completedPost)
                    }
                    SocialViewModel.invalidateCache()
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isUploading = false
                        self.uploadingPost = nil
                    }
                }
                
            } catch {
                print("❌ Background post upload failed: \(error)")
                await MainActor.run {
                    self.isUploading = false
                    self.uploadFailed = true
                }
            }
        }
    }
    
    func dismissFailure() {
        uploadFailed = false
        uploadingPost = nil
    }
}
