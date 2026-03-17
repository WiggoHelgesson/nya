import Foundation
import UIKit
import CoreLocation
import Combine
import SwiftUI
import Supabase

@MainActor
class PostUploadManager: ObservableObject {
    static let shared = PostUploadManager()
    
    enum VerificationState {
        case none, verifying, approved, rejected
    }
    
    @Published var uploadingPost: SocialWorkoutPost?
    @Published var isUploading = false
    @Published var uploadFailed = false
    @Published var verificationState: VerificationState = .none
    
    private var pendingUploadTask: Task<Void, Never>?
    
    struct UploadContext {
        let post: WorkoutPost
        let routeImage: UIImage?
        let userImage: UIImage?
        let userImages: [UIImage]
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
        let requiresModeration: Bool
        
        init(post: WorkoutPost, routeImage: UIImage?, userImage: UIImage?, userImages: [UIImage], earnedPoints: Int, isLivePhoto: Bool, activityType: String, exercisesData: [GymExercisePost]?, userId: String?, userName: String?, userAvatarUrl: String?, hasPB: Bool, pbExerciseName: String, pbValue: String, stravaConnected: Bool, stravaTitle: String, stravaDescription: String, stravaDuration: Int, stravaDistance: Double, stravaRouteCoordinates: [CLLocationCoordinate2D], isPublic: Bool, requiresModeration: Bool = false) {
            self.post = post
            self.routeImage = routeImage
            self.userImage = userImage
            self.userImages = userImages
            self.earnedPoints = earnedPoints
            self.isLivePhoto = isLivePhoto
            self.activityType = activityType
            self.exercisesData = exercisesData
            self.userId = userId
            self.userName = userName
            self.userAvatarUrl = userAvatarUrl
            self.hasPB = hasPB
            self.pbExerciseName = pbExerciseName
            self.pbValue = pbValue
            self.stravaConnected = stravaConnected
            self.stravaTitle = stravaTitle
            self.stravaDescription = stravaDescription
            self.stravaDuration = stravaDuration
            self.stravaDistance = stravaDistance
            self.stravaRouteCoordinates = stravaRouteCoordinates
            self.isPublic = isPublic
            self.requiresModeration = requiresModeration
        }
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
        verificationState = .none
        
        pendingUploadTask = Task {
            do {
                try await WorkoutService.shared.saveWorkoutPost(
                    context.post,
                    routeImage: context.routeImage,
                    userImage: context.userImage,
                    userImages: context.userImages,
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
                
                // Fetch the real post from DB so it includes uploaded image URLs
                var completedPost: SocialWorkoutPost?
                do {
                    let fetched: SocialWorkoutPost = try await SupabaseConfig.supabase
                        .from("workout_posts")
                        .select("""
                            *,
                            profiles!inner(username, avatar_url, is_pro_member),
                            workout_post_likes(count),
                            workout_post_comments(count)
                        """)
                        .eq("id", value: context.post.id)
                        .single()
                        .execute()
                        .value
                    completedPost = fetched
                } catch {
                    print("⚠️ Could not fetch completed post from DB, using local fallback")
                    completedPost = SocialWorkoutPost(
                        from: context.post,
                        userName: context.userName,
                        userAvatarUrl: context.userAvatarUrl,
                        userIsPro: RevenueCatManager.shared.isProMember
                    )
                }
                
                // AI moderation for live photo posts (runs synchronously so toast updates are visible)
                if context.requiresModeration, let imageUrl = completedPost?.userImageUrl {
                    await MainActor.run { self.verificationState = .verifying }
                    do {
                        struct ModerateBody: Encodable {
                            let postId: String
                            let imageUrl: String
                        }
                        struct ModerateResponse: Decodable {
                            let status: String
                        }
                        let response: ModerateResponse = try await SupabaseConfig.supabase.functions
                            .invoke("moderate-post", options: .init(body: ModerateBody(postId: context.post.id, imageUrl: imageUrl)))
                        let approved = response.status == "approved"
                        await MainActor.run {
                            self.verificationState = approved ? .approved : .rejected
                        }
                        if approved {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            await MainActor.run { self.verificationState = .none }
                        }
                        // .rejected stays visible until user dismisses
                    } catch {
                        print("⚠️ Moderation check failed, defaulting to approved: \(error)")
                        await MainActor.run { self.verificationState = .approved }
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run { self.verificationState = .none }
                    }
                }
                
                await MainActor.run {
                    if context.isPublic, let post = completedPost {
                        SocialViewModel.shared.insertPostAtTop(post)
                    }
                    SocialViewModel.invalidateCache()
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isUploading = false
                        // Keep uploadingPost alive when rejected so the banner stays visible
                        // until the user taps X (dismissVerification clears it)
                        if self.verificationState != .rejected {
                            self.uploadingPost = nil
                        }
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
        verificationState = .none
    }
    
    func dismissVerification() {
        verificationState = .none
        uploadingPost = nil
    }
}
