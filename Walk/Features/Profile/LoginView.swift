import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    enum Phase: Equatable {
        case phone
        case verificationCode
    }

    @Published var phone = ""
    @Published var code = ""
    @Published var phase: Phase = .phone
    @Published var verificationID: String?
    @Published private(set) var resendAvailableAt: Date?
    @Published private(set) var account: AccountResponse?
    @Published private(set) var didAuthenticate = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let sendCode: (String) async throws -> VerificationCodeResponse
    private let createSession: (String, String) async throws -> Void
    private let loadAccount: () async throws -> AccountResponse

    init(accountService: any AccountServicing) {
        self.sendCode = { try await accountService.sendVerificationCode(phone: $0) }
        self.createSession = { verificationID, code in
            _ = try await accountService.createSession(verificationID: verificationID, code: code)
        }
        self.loadAccount = { try await accountService.currentAccount() }
    }

    init(
        sendCode: @escaping (String) async throws -> VerificationCodeResponse,
        createSession: @escaping (String, String) async throws -> Void,
        loadAccount: @escaping () async throws -> AccountResponse
    ) {
        self.sendCode = sendCode
        self.createSession = createSession
        self.loadAccount = loadAccount
    }

    static func normalizedPhone(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.range(of: #"^\+[1-9][0-9]{1,14}$"#, options: .regularExpression) != nil {
            return trimmed
        }
        if trimmed.range(of: #"^1[3-9][0-9]{9}$"#, options: .regularExpression) != nil {
            return "+86" + trimmed
        }
        return nil
    }

    var canSendCode: Bool {
        Self.normalizedPhone(phone) != nil
    }

    var canLogin: Bool {
        verificationID != nil && !code.isEmpty
    }

    func sendVerificationCode() async {
        guard let normalizedPhone = Self.normalizedPhone(phone) else {
            errorMessage = "请输入 11 位手机号或 +86 开头的国际格式，例如 13800138000"
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let response = try await sendCode(normalizedPhone)
            verificationID = response.verificationId
            resendAvailableAt = response.resendAvailableAt
            phase = .verificationCode
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func login() async {
        guard let verificationID, canLogin else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await createSession(verificationID, code)
            account = try await loadAccount()
            didAuthenticate = true
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        guard let apiError = error as? APIClientError else { return error.localizedDescription }
        if case .api(let code, _, _, let details) = apiError,
           code == "verification_send_throttled",
           let retryAt = details?.retryAvailableAt {
            return "发送过于频繁，请在 \(retryAt.formatted(date: .omitted, time: .shortened)) 后重试"
        }
        return apiError.errorDescription ?? error.localizedDescription
    }
}

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @State private var completedAuthentication = false
    let onAuthenticated: (AccountResponse) -> Void
    let onCancel: () -> Void

    init(
        accountService: any AccountServicing,
        onAuthenticated: @escaping (AccountResponse) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(accountService: accountService))
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
    }

    init(
        viewModel: LoginViewModel,
        onAuthenticated: @escaping (AccountResponse) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            HomePageBackground().ignoresSafeArea()
            MountainSilhouetteViewForLogin().ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.xl) {
                Spacer()
                PageHeroHeader(title: "登录 Walk", subtitle: "使用手机号验证码继续你的个人任务")
                WalkPanel {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        EntryTextField(title: "手机号", text: $viewModel.phone, keyboardType: .phonePad)
                            .disabled(viewModel.phase == .verificationCode)

                        if viewModel.phase == .phone && !viewModel.phone.isEmpty && !viewModel.canSendCode {
                            Text("支持 11 位手机号或 +86 开头的国际格式")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        if viewModel.phase == .verificationCode {
                            EntryTextField(title: "验证码", text: $viewModel.code, keyboardType: .numberPad)
                            Button("登录") { Task { await viewModel.login() } }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColors.interactionPrimary)
                                .disabled(!viewModel.canLogin || viewModel.isSubmitting)

                            Button("重新发送验证码") { Task { await viewModel.sendVerificationCode() } }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppColors.textSecondary)
                                .disabled(viewModel.isSubmitting)
                        } else {
                            Button("获取验证码") { Task { await viewModel.sendVerificationCode() } }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColors.interactionPrimary)
                                .disabled(!viewModel.canSendCode || viewModel.isSubmitting)
                        }

                        if viewModel.isSubmitting {
                            ProgressView().tint(AppColors.interactionPrimary)
                        }
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(AppColors.statusCancelled)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.bottom, Spacing.xxl)
        }
        .foregroundStyle(AppColors.textPrimary)
        .navigationTitle("登录")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.didAuthenticate) { authenticated in
            guard authenticated, let account = viewModel.account else { return }
            completedAuthentication = true
            onAuthenticated(account)
        }
        .onDisappear {
            if !completedAuthentication { onCancel() }
        }
    }
}

private struct MountainSilhouetteViewForLogin: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: size.width * 0.2, y: size.height * 0.52))
            path.addLine(to: CGPoint(x: size.width * 0.52, y: size.height * 0.35))
            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.62))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
            context.fill(path, with: .color(AppColors.surfaceDivider))
        }
    }
}
