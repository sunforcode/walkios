import SwiftUI

struct ContentSection<Content: View>: View {
    let title: String?
    var subtitle: String? = nil
    var accessibilityLabel: String? = nil
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        accessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessibilityLabel = accessibilityLabel
        self.content = content()
    }

    var body: some View {
        accessibleSection
    }

    @ViewBuilder
    private var accessibleSection: some View {
        let section = VStack(alignment: .leading, spacing: Spacing.md) {
            if let title {
                SectionHeader(title: title, subtitle: subtitle)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.xl)

        if let accessibilityLabel {
            section.accessibilityLabel(accessibilityLabel)
        } else {
            section
        }
    }
}

#if DEBUG
#Preview("ContentSection.default") {
    ContentSection(
        title: ComponentPreviewFixtures.sectionTitle,
        subtitle: ComponentPreviewFixtures.supportingText
    ) {
        WalkCard {
            Text(ComponentPreviewFixtures.longSupportingText)
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}
#endif
