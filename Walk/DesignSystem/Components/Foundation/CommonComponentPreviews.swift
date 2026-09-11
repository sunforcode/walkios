#if DEBUG
import SwiftUI

private struct ComponentPreviewSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.pageBase)
    }
}

#Preview("AvatarButton.default") {
    ComponentPreviewSurface {
        AvatarButton(avatarLabel: "林", accessibilityLabel: "个人与设置", action: {})
    }
}

#Preview("AvatarButton.loading") {
    ComponentPreviewSurface {
        AvatarButton(state: .loading, accessibilityLabel: "账号信息加载中", action: {})
    }
}

#Preview("AvatarButton.unavailable") {
    ComponentPreviewSurface {
        AvatarButton(state: .unavailable, accessibilityLabel: "个人与设置", action: {})
    }
}

#Preview("Card.default") {
    ComponentPreviewSurface {
        WalkCard {
            Text(ComponentPreviewFixtures.longSupportingText)
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Card.longContent") {
    ComponentPreviewSurface {
        WalkCard {
            Text(ComponentPreviewFixtures.longTitle)
                .font(.cardTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("DangerAction.default") {
    ComponentPreviewSurface {
        DangerAction(title: "删除", systemImage: "trash", action: {})
    }
}

#Preview("DangerAction.loading") {
    ComponentPreviewSurface {
        DangerAction(title: "删除", isLoading: true, action: {})
    }
}

#Preview("DateInput.default") {
    ComponentPreviewSurface {
        DateInput(value: .constant(ComponentPreviewFixtures.fixedDate), label: "出发日期")
    }
}

#Preview("DateInput.disabled") {
    ComponentPreviewSurface {
        DateInput(
            value: .constant(ComponentPreviewFixtures.fixedDate),
            label: ComponentPreviewFixtures.longTitle,
            isDisabled: true
        )
    }
}

#Preview("EmptyState.default") {
    ComponentPreviewSurface {
        EmptyStateView(
            title: "暂无内容",
            message: ComponentPreviewFixtures.supportingText,
            icon: "tray"
        )
    }
}

#Preview("FixedActionArea.default") {
    ComponentPreviewSurface {
        FixedActionArea {
            PrimaryAction(title: "继续", fillsWidth: true, action: {})
        }
    }
}

#Preview("FixedActionArea.longAction") {
    ComponentPreviewSurface {
        FixedActionArea {
            PrimaryAction(title: ComponentPreviewFixtures.longTitle, fillsWidth: true, action: {})
        }
    }
}

#Preview("IconButton.default") {
    ComponentPreviewSurface {
        IconButton(systemName: "chevron.left", accessibilityLabel: "返回", action: {})
    }
}

#Preview("IconButton.search") {
    ComponentPreviewSurface {
        IconButton(systemName: "magnifyingglass", accessibilityLabel: "搜索路线", action: {})
    }
}

#Preview("IconButton.overlay") {
    ComponentPreviewSurface {
        IconButton(systemName: "chevron.left", accessibilityLabel: "返回", variant: .overlay, action: {})
    }
}

#Preview("IconButton.compactClose") {
    ComponentPreviewSurface {
        IconButton(systemName: "xmark", accessibilityLabel: "关闭", variant: .compactClose, action: {})
    }
}

#Preview("IconButton.disabled") {
    ComponentPreviewSurface {
        IconButton(systemName: "magnifyingglass", accessibilityLabel: "搜索路线", isDisabled: true, action: {})
    }
}

#Preview("InfoTag.default") {
    ComponentPreviewSurface {
        InfoTag(title: "适中", tone: .neutral)
    }
}

#Preview("InfoTag.overlay") {
    ComponentPreviewSurface {
        InfoTag(title: "高山草甸", tone: .overlay)
    }
}

#Preview("InfoTag.longLabel") {
    ComponentPreviewSurface {
        InfoTag(title: ComponentPreviewFixtures.longTitle, tone: .neutral)
    }
}

#Preview("ListRow.default") {
    ComponentPreviewSurface {
        ListRow {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(ComponentPreviewFixtures.shortTitle)
                    .font(.listTitle)
                Text(ComponentPreviewFixtures.longSupportingText)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

#Preview("ListRow.interactive") {
    ComponentPreviewSurface {
        ListRow(action: {}) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(ComponentPreviewFixtures.longTitle)
                        .font(.listTitle)
                    Text(ComponentPreviewFixtures.supportingText)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.textWeak)
            }
        }
    }
}

#Preview("LoadingState.default") {
    LoadingView(message: "正在加载", variant: .page)
}

#Preview("LoadingState.scene") {
    ComponentPreviewSurface {
        LoadingView(message: "正在加载场景", variant: .scene)
            .frame(height: 180)
    }
}

#Preview("LoadingState.section") {
    ComponentPreviewSurface {
        LoadingView(message: "正在加载区块", variant: .section)
    }
}

#Preview("LoadingState.rowSkeleton") {
    ComponentPreviewSurface {
        LoadingView(variant: .rowSkeleton)
            .frame(height: 56)
    }
}

#Preview("MixedPageShell.default") {
    MixedPageShell {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Rectangle()
                .fill(AppColors.surfaceGlass)
                .frame(height: 180)
            Text("Content Slot")
                .font(.label)
                .padding(Spacing.lg)
        }
    }
}

#Preview("Notice.info") {
    ComponentPreviewSurface {
        NoticeView(message: ComponentPreviewFixtures.supportingText, title: "补充信息", tone: .info)
    }
}

#Preview("Notice.warning") {
    ComponentPreviewSurface {
        NoticeView(message: ComponentPreviewFixtures.longSupportingText, title: "请注意", tone: .warning)
    }
}

#Preview("Notice.danger") {
    ComponentPreviewSurface {
        NoticeView(message: ComponentPreviewFixtures.supportingText, title: "操作未完成", tone: .danger)
    }
}

#Preview("PageTitleBlock.default") {
    ComponentPreviewSurface {
        PageTitleBlock(
            title: ComponentPreviewFixtures.longTitle,
            kicker: "准备出发",
            description: ComponentPreviewFixtures.longSupportingText
        )
    }
}

#Preview("Panel.default") {
    ComponentPreviewSurface {
        WalkPanel(variant: .default) { Text("Content Slot") }
    }
}

#Preview("Panel.edgeAttached") {
    ComponentPreviewSurface {
        WalkPanel(variant: .edgeAttached) { Text("Content Slot") }
    }
}

#Preview("Panel.bottomOverlay") {
    ComponentPreviewSurface {
        WalkPanel(variant: .bottomOverlay) { Text("Content Slot") }
    }
}

#Preview("Panel.glass") {
    ComponentPreviewSurface {
        WalkPanel(variant: .glass) { Text("Content Slot") }
    }
}

#Preview("PrimaryAction.default") {
    ComponentPreviewSurface {
        PrimaryAction(title: "继续", fillsWidth: true, action: {})
    }
}

#Preview("PrimaryAction.compact") {
    ComponentPreviewSurface {
        PrimaryAction(title: "开始", variant: .compact, action: {})
    }
}

#Preview("PrimaryAction.loading") {
    ComponentPreviewSurface {
        PrimaryAction(title: "继续", isLoading: true, fillsWidth: true, action: {})
    }
}

#Preview("PrimaryAction.disabled") {
    ComponentPreviewSurface {
        PrimaryAction(title: ComponentPreviewFixtures.longTitle, isDisabled: true, fillsWidth: true, action: {})
    }
}

#Preview("QuantityStepper.default") {
    ComponentPreviewSurface {
        QuantityStepper(value: .constant(2), minimum: 1, maximum: 5)
    }
}

#Preview("QuantityStepper.minimum") {
    ComponentPreviewSurface {
        QuantityStepper(value: .constant(1), minimum: 1, maximum: 5)
    }
}

#Preview("SecondaryAction.default") {
    ComponentPreviewSurface {
        SecondaryAction(title: "稍后处理", action: {})
    }
}

#Preview("SecondaryAction.inline") {
    ComponentPreviewSurface {
        SecondaryAction(title: "查看详情", variant: .inline, action: {})
    }
}

#Preview("SecondaryAction.overlayCompact") {
    ComponentPreviewSurface {
        SecondaryAction(title: "关闭", variant: .overlayCompact, action: {})
    }
}

#Preview("SecondaryAction.loading") {
    ComponentPreviewSurface {
        SecondaryAction(title: "重新加载", isLoading: true, action: {})
    }
}

#Preview("SectionHeader.default") {
    ComponentPreviewSurface {
        SectionHeader(title: ComponentPreviewFixtures.longTitle, subtitle: ComponentPreviewFixtures.longSupportingText)
    }
}

#Preview("SegmentedControl.default") {
    ComponentPreviewSurface {
        SegmentedControl(options: ComponentPreviewFixtures.segmentOptions, selection: .constant("overview"))
    }
}

#Preview("SelectInput.default") {
    ComponentPreviewSurface {
        SelectInput(
            selection: .constant("moderate"),
            label: "难度",
            placeholder: "请选择难度",
            options: ComponentPreviewFixtures.selectOptions
        )
    }
}

#Preview("SelectInput.disabled") {
    ComponentPreviewSurface {
        SelectInput(
            selection: .constant(nil),
            label: ComponentPreviewFixtures.longTitle,
            placeholder: "请选择",
            options: ComponentPreviewFixtures.selectOptions,
            isDisabled: true
        )
    }
}

#Preview("SelectableOptionCard.default") {
    ComponentPreviewSurface {
        SelectableOptionCard(isSelected: false, action: {}) {
            Text(ComponentPreviewFixtures.longSupportingText)
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("SelectableOptionCard.selected") {
    ComponentPreviewSurface {
        SelectableOptionCard(isSelected: true, action: {}) {
            Text(ComponentPreviewFixtures.shortTitle)
                .font(.cardTitle)
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

#Preview("SelectableOptionCard.disabled") {
    ComponentPreviewSurface {
        SelectableOptionCard(isSelected: false, isEnabled: false, action: {}) {
            Text(ComponentPreviewFixtures.longSupportingText)
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("SettingsListRow.default") {
    ComponentPreviewSurface {
        SettingsListRow(id: "account", label: "账号与安全", onActivate: { _ in })
    }
}

#Preview("SettingsListRow.described") {
    ComponentPreviewSurface {
        SettingsListRow(
            id: "privacy",
            label: ComponentPreviewFixtures.longTitle,
            description: ComponentPreviewFixtures.longSupportingText,
            showsDivider: false,
            onActivate: { _ in }
        )
    }
}

#Preview("SheetHandle.default") {
    ComponentPreviewSurface { SheetHandle() }
}

#Preview("SourceNote.default") {
    ComponentPreviewSurface {
        SourceNote(source: ComponentPreviewFixtures.source, updatedAt: ComponentPreviewFixtures.updatedAt)
    }
}

#Preview("SourceNote.sourceOnly") {
    ComponentPreviewSurface {
        SourceNote(source: ComponentPreviewFixtures.source)
    }
}

#Preview("TextInput.default") {
    ComponentPreviewSurface {
        TextInput(text: .constant("云岭环线"), label: "路线名称", placeholder: "输入路线名称")
    }
}

#Preview("TextInput.disabled") {
    ComponentPreviewSurface {
        TextInput(
            text: .constant(ComponentPreviewFixtures.longTitle),
            label: ComponentPreviewFixtures.longTitle,
            placeholder: "输入内容",
            isDisabled: true
        )
    }
}

#Preview("Timeline.default") {
    ComponentPreviewSurface {
        Timeline(ComponentPreviewFixtures.timelineItems, optionalTime: { $0.time }) { item in
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.title)
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(item.details, id: \.self) { detail in
                    Text(detail)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview("UnavailableState.inline") {
    ComponentPreviewSurface {
        UnavailableStateView(title: "天气暂不可用", message: ComponentPreviewFixtures.longSupportingText)
    }
}

#Preview("UnavailableState.block") {
    ComponentPreviewSurface {
        UnavailableStateView(
            title: "区块内容暂不可用",
            message: ComponentPreviewFixtures.longSupportingText,
            variant: .block
        )
    }
}

#Preview("UtilityPage.default") {
    UtilityPage {
        Text("Content Slot")
            .font(.label)
            .padding(Spacing.lg)
    }
}
#endif
