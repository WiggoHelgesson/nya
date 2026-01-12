import SwiftUI

// MARK: - Skeleton Shimmer Modifier (uses existing shimmer from OptimizedAsyncImage)
// The shimmer() extension is already defined in OptimizedAsyncImage.swift

// MARK: - Basic Skeleton Shapes
struct SkeletonRectangle: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(height: height)
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40
    
    var body: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
            .shimmer()
    }
}

struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    
    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Skeleton Post Card (for Social Feed)
struct SkeletonPostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with avatar and username
            HStack(spacing: 12) {
                SkeletonCircle(size: 44)
                
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonLine(width: 120, height: 14)
                    SkeletonLine(width: 80, height: 12)
                }
                
                Spacer()
                
                SkeletonCircle(size: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Image placeholder
            SkeletonRectangle(height: 300, cornerRadius: 0)
            
            // Action buttons row
            HStack(spacing: 20) {
                SkeletonCircle(size: 24)
                SkeletonCircle(size: 24)
                SkeletonCircle(size: 24)
                Spacer()
                SkeletonCircle(size: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Likes count
            SkeletonLine(width: 100, height: 14)
                .padding(.horizontal, 16)
            
            // Caption lines
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(height: 14)
                SkeletonLine(width: 200, height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Skeleton Profile Header
struct SkeletonProfileHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            SkeletonCircle(size: 80)
            
            // Name
            SkeletonLine(width: 150, height: 18)
            
            // Stats row
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    SkeletonLine(width: 40, height: 18)
                    SkeletonLine(width: 50, height: 12)
                }
                VStack(spacing: 4) {
                    SkeletonLine(width: 40, height: 18)
                    SkeletonLine(width: 50, height: 12)
                }
                VStack(spacing: 4) {
                    SkeletonLine(width: 40, height: 18)
                    SkeletonLine(width: 50, height: 12)
                }
            }
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Skeleton List Row
struct SkeletonListRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 140, height: 16)
                SkeletonLine(width: 200, height: 14)
            }
            
            Spacer()
            
            SkeletonLine(width: 60, height: 30)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Skeleton Exercise Card
struct SkeletonExerciseCard: View {
    var body: some View {
        HStack(spacing: 14) {
            SkeletonRectangle(height: 48, cornerRadius: 12)
                .frame(width: 48)
            
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 120, height: 15)
                SkeletonLine(width: 80, height: 13)
            }
            
            Spacer()
            
            SkeletonLine(width: 50, height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Skeleton Notification Row
struct SkeletonNotificationRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: 44)
            
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 200, height: 14)
                SkeletonLine(width: 100, height: 12)
            }
            
            Spacer()
            
            SkeletonRectangle(height: 44, cornerRadius: 8)
                .frame(width: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Skeleton Store Card
struct SkeletonStoreCard: View {
    var body: some View {
        VStack(spacing: 8) {
            SkeletonCircle(size: 70)
            SkeletonLine(width: 60, height: 12)
        }
        .frame(width: 80)
    }
}

// MARK: - Skeleton Feed View (Multiple Posts)
struct SkeletonFeedView: View {
    var postCount: Int = 3
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(0..<postCount, id: \.self) { _ in
                SkeletonPostCard()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Skeleton Post Card")
                .font(.headline)
            SkeletonPostCard()
            
            Divider()
            
            Text("Skeleton Profile Header")
                .font(.headline)
            SkeletonProfileHeader()
            
            Divider()
            
            Text("Skeleton List Rows")
                .font(.headline)
            SkeletonListRow()
            SkeletonListRow()
            
            Divider()
            
            Text("Skeleton Notification Rows")
                .font(.headline)
            SkeletonNotificationRow()
            SkeletonNotificationRow()
        }
    }
}

