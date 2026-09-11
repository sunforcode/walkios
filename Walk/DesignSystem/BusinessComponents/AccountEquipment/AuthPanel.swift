import Foundation
import SwiftUI

enum AuthPanelStage: Equatable {
    case phone
    case code
    case confirmingFocus
    case focusError
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
    let onRetryFocusTrip: () -> Void

    var body: some View {
        WalkPanel(variant: .glass) {
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
        case .confirmingFocus:
            LoadingView(
                message: "正在确认焦点行程",
                detail: "登录已完成，正在恢复刚才的个人任务。",
                variant: .section
            )
        case .focusError:
            ErrorView(
                message: projection.operationError ?? "暂时无法恢复刚才的个人任务。",
                title: "焦点行程确认失败",
                variant: .form,
                retry: onRetryFocusTrip
            )
        }
    }

    private var phoneContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            FormField(
                label: "手机号",
                requirement: .required,
                assistiveText: "请输入 E.164 国际格式手机号",
                error: projection.fieldError
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
                error: projection.fieldError
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

    private func formTextInput(
        text: Binding<String>,
        label: String,
        placeholder: String
    ) -> some View {
        TextInput(
            text: text,
            label: label,
            placeholder: placeholder,
            isDisabled: projection.isLoading,
            showsLabel: false,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
    }

    private var stageTitle: String {
        switch projection.stage {
        case .phone: "登录 Walk"
        case .code: "输入验证码"
        case .confirmingFocus: "确认焦点行程"
        case .focusError: "继续个人任务"
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
#Preview("AuthPanel.phone") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authPhone) }
}

#Preview("AuthPanel.phoneInvalid") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authPhoneInvalid) }
}

#Preview("AuthPanel.sending") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authSending) }
}

#Preview("AuthPanel.throttled") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authThrottled) }
}

#Preview("AuthPanel.sendFailed") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authSendFailed) }
}

#Preview("AuthPanel.code") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authCode) }
}

#Preview("AuthPanel.codeInvalid") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authCodeInvalid) }
}

#Preview("AuthPanel.expired") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authExpired) }
}

#Preview("AuthPanel.verifying") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authVerifying) }
}

#Preview("AuthPanel.confirmingFocus") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authConfirmingFocus) }
}

#Preview("AuthPanel.focusError") {
    BusinessComponentPreviewHost { AuthPanel.preview(BusinessComponentPreviewFixtures.authFocusError) }
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
            onResendCode: {},
            onRetryFocusTrip: {}
        )
    }
}
#endif
