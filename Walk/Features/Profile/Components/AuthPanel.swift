import Foundation
import SwiftUI
import WalkData
import WalkDesignSystem

enum AuthPanelStage: Equatable {
    case phone
    case code
}

struct AuthPanelProjection: Equatable {
    let stage: AuthPanelStage
    let sourceContext: String
    var phone: String = ""
    var code: String = ""
    var verificationID: String? = nil
    var expiresAt: Date? = nil
    var resendAvailableAt: Date? = nil
    var retryAvailableAt: Date? = nil
    var fieldError: String? = nil
    var operationError: String? = nil
    var isLoading = false
    var isPrimaryEnabled = true
    var isSecondaryEnabled = true
}

struct AuthPanel: View {
    let projection: AuthPanelProjection
    let onClose: () -> Void
    let onChangePhone: (String) -> Void
    let onSendCode: () -> Void
    let onChangeCode: (String) -> Void
    let onVerifyCode: () -> Void
    let onResendCode: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        WalkPanel(variant: .glass) {
            // PAGE-LOGIN：面板内容自高贴底；内容超出最大高时才退化为面板内部滚动。
            ViewThatFits(in: .vertical) {
                panelContent
                ScrollView {
                    panelContent
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SheetHandle()

            header

            Text(projection.sourceContext)
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            stageContent

            Text("首次验证通过后将直接建立或复用 Walk 账号")
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(stageTitle)
                .font(.authTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            IconButton(
                systemName: "xmark",
                accessibilityLabel: "关闭登录",
                variant: .compactClose,
                isDisabled: projection.isLoading,
                action: onClose
            )
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch projection.stage {
        case .phone:
            phoneContent
        case .code:
            codeContent
        }
    }

    private var phoneContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            FormField(
                label: "手机号",
                requirement: .required,
                assistiveText: "请输入 E.164 国际格式手机号",
                error: projection.fieldError,
                isFocused: isFieldFocused
            ) {
                formTextInput(
                    text: Binding(get: { projection.phone }, set: onChangePhone),
                    label: "手机号",
                    placeholder: "+8613800138000"
                )
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
            }

            if let retryAvailableAt = projection.retryAvailableAt {
                NoticeView(
                    message: "发送受到限制，可在 \(formattedTime(retryAvailableAt)) 后重试。",
                    title: "暂时无法重新发送",
                    icon: "clock",
                    tone: .warning,
                    variant: .form
                )
            }

            if let operationError = projection.operationError {
                ErrorView(
                    message: operationError,
                    title: "验证码发送失败",
                    variant: .form
                )
            }

            PrimaryAction(
                title: "获取验证码",
                isLoading: projection.isLoading,
                isDisabled: !projection.isPrimaryEnabled,
                fillsWidth: true,
                action: onSendCode
            )
        }
    }

    private var codeContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            FormField(
                label: "验证码",
                requirement: .required,
                assistiveText: "验证码始终作为文本处理并保留前导零",
                error: projection.fieldError,
                isFocused: isFieldFocused
            ) {
                formTextInput(
                    text: Binding(get: { projection.code }, set: onChangeCode),
                    label: "验证码",
                    placeholder: "输入验证码"
                )
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
            }

            if let verificationNotice {
                NoticeView(
                    message: verificationNotice,
                    title: "验证码",
                    icon: "clock",
                    tone: .info,
                    variant: .form
                )
            }

            if let operationError = projection.operationError {
                ErrorView(
                    message: operationError,
                    title: "验证码验证失败",
                    variant: .form
                )
            }

            PrimaryAction(
                title: "登录并继续",
                isLoading: projection.isLoading,
                isDisabled: !projection.isPrimaryEnabled,
                fillsWidth: true,
                action: onVerifyCode
            )

            SecondaryAction(
                title: "重新获取验证码",
                isDisabled: !projection.isSecondaryEnabled || projection.isLoading,
                fillsWidth: true,
                action: onResendCode
            )
        }
    }

    /// FormField 自带容器样式（surfaceInput 底 + 描边），内部只接受裸控件；
    /// 嵌套自带容器的 TextInput 会产生双层边框。焦点由本组件持有并驱动 FormField 聚焦态。
    private func formTextInput(
        text: Binding<String>,
        label: String,
        placeholder: String
    ) -> some View {
        TextField(placeholder, text: text)
            .tint(AppColors.interactionPrimary)
            .focused($isFieldFocused)
            .submitLabel(.done)
            .disabled(projection.isLoading)
            .accessibilityLabel(label)
    }

    private var stageTitle: String {
        switch projection.stage {
        case .phone: "登录 Walk"
        case .code: "输入验证码"
        }
    }

    private var verificationNotice: String? {
        var parts: [String] = []
        if let expiresAt = projection.expiresAt {
            parts.append("本次验证有效至 \(formattedTime(expiresAt))")
        }
        if let resendAvailableAt = projection.resendAvailableAt {
            parts.append("可在 \(formattedTime(resendAvailableAt)) 后重新获取")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "；")
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

#if DEBUG
extension AuthPanelProjection {
    private static let fixedExpiry = Date(timeIntervalSince1970: 1_789_690_500)

    private static let fixedResend = Date(timeIntervalSince1970: 1_789_689_900)

    private static let fixedRetry = Date(timeIntervalSince1970: 1_789_690_020)

    static let phone = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "+8613800138000"
    )

    static let phoneInvalid = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "138",
        fieldError: "请输入有效的 E.164 手机号",
        isPrimaryEnabled: false
    )

    static let sending = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "+8613800138000",
        isLoading: true,
        isPrimaryEnabled: false
    )

    static let throttled = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "+8613800138000",
        retryAvailableAt: AuthPanelProjection.fixedRetry,
        isPrimaryEnabled: false
    )

    static let sendFailed = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "+8613800138000",
        operationError: "验证码发送失败，请保留手机号后重试。"
    )

    static let code = AuthPanelProjection(
        stage: .code,
        sourceContext: "完成验证后将继续刚才的任务。",
        phone: "+8613800138000",
        code: "012345",
        verificationID: "verification-001",
        expiresAt: AuthPanelProjection.fixedExpiry,
        resendAvailableAt: AuthPanelProjection.fixedResend
    )

    static let codeInvalid = AuthPanelProjection(
        stage: .code,
        sourceContext: "完成验证后将继续刚才的任务。",
        phone: "+8613800138000",
        code: "01234",
        verificationID: "verification-001",
        expiresAt: AuthPanelProjection.fixedExpiry,
        resendAvailableAt: AuthPanelProjection.fixedResend,
        fieldError: "验证码不正确",
        isPrimaryEnabled: false
    )

    static let expired = AuthPanelProjection(
        stage: .code,
        sourceContext: "完成验证后将继续刚才的任务。",
        phone: "+8613800138000",
        code: "012345",
        verificationID: "verification-001",
        expiresAt: AuthPanelProjection.fixedExpiry,
        resendAvailableAt: AuthPanelProjection.fixedResend,
        operationError: "验证码已过期，请重新获取。",
        isPrimaryEnabled: false
    )

    static let verifying = AuthPanelProjection(
        stage: .code,
        sourceContext: "完成验证后将继续刚才的任务。",
        phone: "+8613800138000",
        code: "012345",
        verificationID: "verification-001",
        expiresAt: AuthPanelProjection.fixedExpiry,
        resendAvailableAt: AuthPanelProjection.fixedResend,
        isLoading: true,
        isPrimaryEnabled: false,
        isSecondaryEnabled: false
    )


}

#Preview("AuthPanel.phone") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.phone) }
}

#Preview("AuthPanel.phoneInvalid") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.phoneInvalid) }
}

#Preview("AuthPanel.sending") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.sending) }
}

#Preview("AuthPanel.throttled") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.throttled) }
}

#Preview("AuthPanel.sendFailed") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.sendFailed) }
}

#Preview("AuthPanel.code") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.code) }
}

#Preview("AuthPanel.codeInvalid") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.codeInvalid) }
}

#Preview("AuthPanel.expired") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.expired) }
}

#Preview("AuthPanel.verifying") {
    BusinessComponentPreviewHost { AuthPanel.preview(AuthPanelProjection.verifying) }
}



private extension AuthPanel {
    static func preview(_ projection: AuthPanelProjection) -> AuthPanel {
        AuthPanel(
            projection: projection,
            onClose: {},
            onChangePhone: { _ in },
            onSendCode: {},
            onChangeCode: { _ in },
            onVerifyCode: {},
            onResendCode: {}
        )
    }
}
#endif
