import SwiftUI

struct TripRouteVersionCardProjection: Equatable {
    let adoptedVersionLabel: String
    var currentPublicVersionLabel: String?
    let relationship: TripRouteVersionRelationship
    let migrationEligible: Bool
    var comparisonStatus: String?
    var differences: [TripRouteDifferenceProjection]
    var unavailableCategories: [String]
    var otherRelevantChanges: [String]
    var otherRelevantChangeStatus: String?
    var differencesExpanded: Bool
    var canViewCurrentRoute: Bool
    var isMigrating: Bool
    var migrationResult: TripNoticeProjection?

    var hasExpandableDetails: Bool {
        !differences.isEmpty
            || !unavailableCategories.isEmpty
            || !otherRelevantChanges.isEmpty
            || otherRelevantChangeStatus != nil
    }
}

extension TripBusinessComponents {
    struct TripRouteVersionCard: View {
        let projection: TripRouteVersionCardProjection
        let onViewCurrentRoute: () -> Void
        let onToggleDifferences: () -> Void
        let onRequestMigration: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header

                relationshipDescription

                actions

                if projection.differencesExpanded {
                    differenceArea
                }

                if let migrationResult = projection.migrationResult {
                    NoticeView(
                        message: migrationResult.message,
                        title: migrationResult.title,
                        icon: "exclamationmark.triangle",
                        tone: migrationResult.tone.noticeTone
                    )
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        AppColors.interactionPrimary.opacity(0.11),
                        AppColors.surfacePrimary.opacity(0.70),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.interactionPrimary.opacity(0.24), lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
        }

        private var header: some View {
            HStack(alignment: .top, spacing: Spacing.md) {
                Text(relationshipTitle)
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                InfoTag(title: versionTagText, tone: .neutral)
            }
        }

        @ViewBuilder
        private var relationshipDescription: some View {
            switch projection.relationship {
            case .current:
                NoticeView(
                    message: "个人行程继续使用生成时的路线依据。",
                    title: "行程采用版本已冻结",
                    tone: .info
                )

            case .currentPublicVersionUnavailable:
                NoticeView(
                    message: "冻结路线依据仍可查看，不以采用版本或其他版本替代当前公开版本。",
                    title: "当前公开版本暂不可取得",
                    tone: .warning
                )

            case .newerPublicVersionAvailable:
                NoticeView(
                    message: "当前公开路线已有更新；本次行程仍使用生成时版本。",
                    title: "\(projection.adoptedVersionLabel) → \(projection.currentPublicVersionLabel ?? "当前公开版本")",
                    tone: .info
                )

                if let comparisonStatus = tripNonEmpty(projection.comparisonStatus) {
                    Text(comparisonStatus)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        @ViewBuilder
        private var actions: some View {
            if projection.relationship == .newerPublicVersionAvailable {
                TripWrapLayout {
                    if projection.hasExpandableDetails {
                        SecondaryAction(
                            title: projection.differencesExpanded ? "收起版本差异" : "查看版本差异",
                            variant: .inline,
                            action: onToggleDifferences
                        )
                    }

                    if projection.canViewCurrentRoute {
                        SecondaryAction(
                            title: "查看当前公开路线",
                            variant: .inline,
                            action: onViewCurrentRoute
                        )
                    }
                }

                if projection.migrationEligible {
                    PrimaryAction(
                        title: "迁移到\(projection.currentPublicVersionLabel ?? "当前公开版本")",
                        isLoading: projection.isMigrating,
                        isDisabled: projection.isMigrating,
                        fillsWidth: true,
                        action: onRequestMigration
                    )
                }
            } else if projection.canViewCurrentRoute
                        && projection.relationship != .currentPublicVersionUnavailable {
                SecondaryAction(
                    title: "查看当前公开路线",
                    variant: .inline,
                    action: onViewCurrentRoute
                )
            }
        }

        @ViewBuilder
        private var differenceArea: some View {
            if !projection.hasExpandableDetails { EmptyView() } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Rectangle()
                        .fill(AppColors.surfaceDivider)
                        .frame(height: 1)
                        .accessibilityHidden(true)

                    ForEach(projection.differences) { item in
                        differenceRow(label: item.label, value: item.detail)
                    }
                    ForEach(Array(projection.unavailableCategories.enumerated()), id: \.offset) { _, category in
                        differenceRow(label: category, value: "该类别不可比较")
                    }
                    ForEach(Array(projection.otherRelevantChanges.enumerated()), id: \.offset) { _, change in
                        differenceRow(label: "其他相关变化", value: change)
                    }
                    if let status = tripNonEmpty(projection.otherRelevantChangeStatus) {
                        differenceRow(label: "其他相关变化", value: status)
                    }
                }
            }
        }

        private var relationshipTitle: String {
            switch projection.relationship {
            case .current: "行程采用版本已冻结"
            case .newerPublicVersionAvailable: "路线版本已有更新"
            case .currentPublicVersionUnavailable: "当前公开版本暂不可取得"
            }
        }

        private var versionTagText: String {
            switch projection.relationship {
            case .current:
                "采用版本 · \(projection.adoptedVersionLabel)"
            case .newerPublicVersionAvailable:
                "\(projection.adoptedVersionLabel) → \(projection.currentPublicVersionLabel ?? "当前公开版本")"
            case .currentPublicVersionUnavailable:
                "采用版本 · \(projection.adoptedVersionLabel)"
            }
        }

        private func differenceRow(label: String, value: String) -> some View {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    Text(label)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                        .frame(width: 62, alignment: .leading)
                    Text(value)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(label)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                    Text(value)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#if DEBUG
#Preview("TripRouteVersionCard.current") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteVersionCard(
            projection: BusinessComponentPreviewFixtures.tripRouteVersionCurrent,
            onViewCurrentRoute: {},
            onToggleDifferences: {},
            onRequestMigration: {}
        )
    }
}

#Preview("TripRouteVersionCard.newerCollapsed") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteVersionCard(
            projection: BusinessComponentPreviewFixtures.tripRouteVersionNewerCollapsed,
            onViewCurrentRoute: {},
            onToggleDifferences: {},
            onRequestMigration: {}
        )
    }
}

#Preview("TripRouteVersionCard.newerExpanded") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteVersionCard(
            projection: BusinessComponentPreviewFixtures.tripRouteVersionNewerExpanded,
            onViewCurrentRoute: {},
            onToggleDifferences: {},
            onRequestMigration: {}
        )
    }
}

#Preview("TripRouteVersionCard.newerReadonly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteVersionCard(
            projection: BusinessComponentPreviewFixtures.tripRouteVersionNewerReadonly,
            onViewCurrentRoute: {},
            onToggleDifferences: {},
            onRequestMigration: {}
        )
    }
}

#Preview("TripRouteVersionCard.publicRouteUnavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteVersionCard(
            projection: BusinessComponentPreviewFixtures.tripRouteVersionUnavailable,
            onViewCurrentRoute: {},
            onToggleDifferences: {},
            onRequestMigration: {}
        )
    }
}

#Preview("TripRouteVersionCard.migrationSubmitting") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteVersionCard(
            projection: BusinessComponentPreviewFixtures.tripRouteVersionMigrating,
            onViewCurrentRoute: {},
            onToggleDifferences: {},
            onRequestMigration: {}
        )
    }
}

#Preview("TripRouteVersionCard.migrationFailed") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteVersionCard(
            projection: BusinessComponentPreviewFixtures.tripRouteVersionMigrationFailed,
            onViewCurrentRoute: {},
            onToggleDifferences: {},
            onRequestMigration: {}
        )
    }
}

#Preview("TripRouteVersionCard.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteVersionCard(
            projection: BusinessComponentPreviewFixtures.tripRouteVersionLong,
            onViewCurrentRoute: {},
            onToggleDifferences: {},
            onRequestMigration: {}
        )
    }
}
#endif
