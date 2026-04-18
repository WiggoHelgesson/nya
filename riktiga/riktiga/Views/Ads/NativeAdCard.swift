import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds

/// SwiftUI wrapper that renders an AdMob NativeAd in a card that mirrors the
/// visual language of `WorkoutPostCard` so ads blend naturally into the feed.
struct NativeAdCard: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        // Let SwiftUI manage the root frame via sizeThatFits; do NOT set
        // translatesAutoresizingMaskIntoConstraints = false here or the view
        // can be rendered smaller than its Auto Layout content, which causes
        // subviews (CTA/body) to spill outside adView.bounds and triggers the
        // AdMob validator's "Advertiser assets outside native ad view" error.
        adView.backgroundColor = .systemBackground

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(container)

        // Top row: icon + headline + "Annons"-label + advertiser
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.layer.cornerRadius = 16
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        iconView.backgroundColor = .secondarySystemBackground

        let headlineLabel = UILabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        headlineLabel.numberOfLines = 1

        let advertiserLabel = UILabel()
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        advertiserLabel.font = .systemFont(ofSize: 12, weight: .regular)
        advertiserLabel.textColor = .secondaryLabel
        advertiserLabel.numberOfLines = 1

        let sponsorPill = UILabel()
        sponsorPill.translatesAutoresizingMaskIntoConstraints = false
        sponsorPill.text = "Annons"
        sponsorPill.font = .systemFont(ofSize: 10, weight: .semibold)
        sponsorPill.textColor = .secondaryLabel
        sponsorPill.backgroundColor = .secondarySystemBackground
        sponsorPill.textAlignment = .center
        sponsorPill.layer.cornerRadius = 4
        sponsorPill.clipsToBounds = true
        sponsorPill.setContentHuggingPriority(.required, for: .horizontal)
        sponsorPill.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [headlineLabel, advertiserLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [iconView, textStack, sponsorPill])
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.axis = .horizontal
        topRow.spacing = 10
        topRow.alignment = .center

        // Media
        let mediaView = MediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.layer.cornerRadius = 12
        mediaView.clipsToBounds = true
        mediaView.backgroundColor = .secondarySystemBackground

        // Body
        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = .label
        bodyLabel.numberOfLines = 3

        // CTA
        let ctaButton = UIButton(type: .system)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.backgroundColor = UIColor(red: 10/255, green: 85/255, blue: 96/255, alpha: 1)
        ctaButton.layer.cornerRadius = 10
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        ctaButton.isUserInteractionEnabled = false // AdMob requires parent handles the tap

        let contentStack = UIStackView(arrangedSubviews: [topRow, mediaView, bodyLabel, ctaButton])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.alignment = .fill
        container.addSubview(contentStack)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: container.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            sponsorPill.heightAnchor.constraint(equalToConstant: 18),
            sponsorPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),

            mediaView.heightAnchor.constraint(equalTo: mediaView.widthAnchor, multiplier: 9/16),

            ctaButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        adView.iconView = iconView
        adView.headlineView = headlineLabel
        adView.advertiserView = advertiserLabel
        adView.mediaView = mediaView
        adView.bodyView = bodyLabel
        adView.callToActionView = ctaButton

        return adView
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {
        uiView.nativeAd = nativeAd

        (uiView.headlineView as? UILabel)?.text = nativeAd.headline
        (uiView.advertiserView as? UILabel)?.text = nativeAd.advertiser ?? "Sponsrad"
        (uiView.bodyView as? UILabel)?.text = nativeAd.body
        (uiView.bodyView as? UILabel)?.isHidden = (nativeAd.body ?? "").isEmpty
        (uiView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (uiView.iconView as? UIImageView)?.isHidden = nativeAd.icon == nil

        if let cta = uiView.callToActionView as? UIButton {
            cta.setTitle(nativeAd.callToAction ?? "Läs mer", for: .normal)
        }

        uiView.mediaView?.mediaContent = nativeAd.mediaContent
    }

    /// Report the actual Auto-Layout-fitting height back to SwiftUI so the
    /// hosting view never clips the ad contents (which would trigger the
    /// "Advertiser assets outside native ad view" validator warning).
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NativeAdView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        uiView.layoutIfNeeded()
        let fitting = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: fitting.height)
    }
}
#else
struct NativeAdCard: View {
    let nativeAd: Any
    var body: some View { EmptyView() }
}
#endif
