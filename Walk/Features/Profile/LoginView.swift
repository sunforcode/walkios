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
        return nil
    }

    var canSendCode: Bool {
        Self.normalizedPhone(phone) != nil
    }

    var canLogin: Bool {
        verificationID != nil
            && code.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil
    }

    func sendVerificationCode() async {
        guard let normalizedPhone = Self.normalizedPhone(phone) else {
            errorMessage = "请输入有效手机号"
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
        } catch {
            errorMessage = Self.message(for: error)
            return
        }

        didAuthenticate = true
        account = try? await loadAccount()
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

private enum LoginFocusedField: Hashable {
    case phone
    case code
}

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LoginViewModel
    @State private var didResolveAuthenticationFlow = false
    @State private var now = Date()
    @FocusState private var focusedField: LoginFocusedField?
    let intent: PendingAuthIntent?
    let onAuthenticated: () -> Void
    let onCancel: () -> Void

    init(
        accountService: any AccountServicing,
        intent: PendingAuthIntent? = nil,
        onAuthenticated: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(accountService: accountService))
        self.intent = intent
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
    }

    init(
        viewModel: LoginViewModel,
        intent: PendingAuthIntent? = nil,
        onAuthenticated: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.intent = intent
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                LoginNightRidgeScene(phase: viewModel.phase)
                    .ignoresSafeArea()

                WalkPanel(surface: .glass) {
                    ViewThatFits(in: .vertical) {
                        panelContent
                        ScrollView(.vertical, showsIndicators: false) {
                            panelContent
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
                .frame(maxWidth: 430)
                .frame(maxHeight: max(0, geometry.size.height - 58), alignment: .bottom)
                .padding(12)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.pageBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = viewModel.phase == .phone ? .phone : .code
            }
        }
        .onChange(of: viewModel.phase) { phase in
            focusedField = phase == .phone ? .phone : .code
        }
        .onChange(of: viewModel.didAuthenticate) { authenticated in
            guard authenticated else { return }
            didResolveAuthenticationFlow = true
            onAuthenticated()
        }
        .onDisappear {
            if !didResolveAuthenticationFlow { onCancel() }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                now = Date()
            }
        }
    }

    private func cancelAuthentication() {
        guard !didResolveAuthenticationFlow else { return }
        didResolveAuthenticationFlow = true
        onCancel()
        dismiss()
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SheetHandle()
                .overlay(alignment: .topTrailing) {
                    GlassIconButton(systemName: "xmark", action: cancelAuthentication)
                    .offset(y: -Spacing.sm)
                }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(viewModel.phase == .phone ? "登录 Walk" : "输入验证码")
                    .font(.sectionTitle)

                Text(contextualNote)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.phase == .phone {
                phoneField

                if let errorMessage = viewModel.errorMessage {
                    NoticeView(
                        message: errorMessage,
                        title: "验证码发送失败",
                        icon: "exclamationmark.triangle",
                        tone: .danger,
                        variant: .form
                    )
                }

                PrimaryAction(
                    title: "获取验证码",
                    isLoading: viewModel.isSubmitting,
                    isDisabled: !viewModel.canSendCode,
                    fillsWidth: true
                ) {
                    Task { await viewModel.sendVerificationCode() }
                }
            } else {
                codeField

                NoticeView(
                    message: resendNotice,
                    title: "验证码",
                    icon: "clock",
                    tone: .info,
                    variant: .form
                )

                PrimaryAction(
                    title: "登录并继续",
                    isLoading: viewModel.isSubmitting,
                    isDisabled: !viewModel.canLogin,
                    fillsWidth: true
                ) {
                    Task { await viewModel.login() }
                }

                SecondaryAction(
                    title: "重新获取验证码",
                    variant: .default,
                    isLoading: false,
                    isDisabled: !canResend || viewModel.isSubmitting,
                    fillsWidth: true
                ) {
                    Task { await viewModel.sendVerificationCode() }
                }
            }

            Text("首次验证通过后直接建立 Walk 账号")
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private var phoneField: some View {
        FormField(
            label: "手机号",
            requirement: .required,
            assistiveText: "请输入可接收验证码的手机号",
            error: phoneValidationError,
            isFocused: focusedField == .phone
        ) {
            TextField("手机号", text: $viewModel.phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .focused($focusedField, equals: .phone)
                .submitLabel(.continue)
                .onSubmit {
                    guard viewModel.canSendCode else { return }
                    Task { await viewModel.sendVerificationCode() }
                }
                .accessibilityLabel("手机号")
        }
    }

    private var codeField: some View {
        FormField(
            label: "验证码",
            requirement: .required,
            assistiveText: "验证码已发送至 \(maskedPhone)",
            error: viewModel.errorMessage,
            isFocused: focusedField == .code
        ) {
            TextField("验证码", text: $viewModel.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .code)
                .submitLabel(.done)
                .onSubmit {
                    guard viewModel.canLogin else { return }
                    Task { await viewModel.login() }
                }
                .accessibilityLabel("验证码")
        }
    }

    private var phoneValidationError: String? {
        guard !viewModel.phone.isEmpty, !viewModel.canSendCode else { return nil }
        return "请输入有效手机号"
    }

    private var maskedPhone: String {
        guard let phone = LoginViewModel.normalizedPhone(viewModel.phone) else { return viewModel.phone }
        let digits = phone.dropFirst()
        guard digits.count > 7 else { return phone }
        return "+\(digits.prefix(3))****\(digits.suffix(4))"
    }

    private var remainingSeconds: Int {
        guard let availableAt = viewModel.resendAvailableAt else { return 0 }
        return max(0, Int(ceil(availableAt.timeIntervalSince(now))))
    }

    private var canResend: Bool {
        remainingSeconds == 0
    }

    private var resendNotice: String {
        remainingSeconds > 0
            ? "\(remainingSeconds) 秒后可重新获取"
            : "现在可以重新获取验证码"
    }

    private var contextualNote: String {
        if viewModel.phase == .verificationCode {
            return "完成验证后将继续刚才的任务。"
        }
        switch intent {
        case .homeStart:
            return "登录后继续开启一次新的徒步行程。"
        case .createTrip:
            return "登录后继续生成这条路线的个人行程。"
        case .profile:
            return "登录后返回“我的”，管理个人资料与装备。"
        case .reauthenticate, nil:
            return "使用手机验证码继续你的个人任务。"
        }
    }
}

private struct LoginNightRidgeScene: View {
    let phase: LoginViewModel.Phase

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppColors.pageMiddle
                .ignoresSafeArea()

            Ellipse()
                .fill(AppColors.interactionPrimary.opacity(0.16))
                .frame(width: 300, height: 220)
                .blur(radius: 70)
                .offset(x: 28, y: -28)

            LoginContourLayer()
                .opacity(0.27)

            LoginMountainLayer()

            LoginRouteGlow(highlightsFinish: phase == .verificationCode)
                .padding(.horizontal, 36)
                .padding(.top, 126)
                .frame(height: 412)

            Text("WALK")
                .font(.ornament(15, weight: .black))
                .tracking(2)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.leading, 24)
                .padding(.top, 60)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct LoginContourLayer: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<7 {
                let inset = CGFloat(index) * 22
                let rect = CGRect(
                    x: -80 + inset,
                    y: 88 + inset * 0.54,
                    width: size.width + 160 - inset * 1.3,
                    height: size.height * 0.42 - inset * 0.28
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(AppColors.interactionPrimary),
                    lineWidth: 1
                )
            }
        }
    }
}

private struct LoginMountainLayer: View {
    var body: some View {
        Canvas { context, size in
            var far = Path()
            far.move(to: CGPoint(x: -size.width * 0.14, y: size.height))
            far.addLine(to: CGPoint(x: -size.width * 0.14, y: size.height * 0.52))
            far.addLine(to: CGPoint(x: size.width * 0.25, y: size.height * 0.31))
            far.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.58))
            far.addLine(to: CGPoint(x: size.width * 1.14, y: size.height * 0.39))
            far.addLine(to: CGPoint(x: size.width * 1.14, y: size.height))
            far.closeSubpath()
            context.fill(far, with: .color(AppColors.surfaceElevated.opacity(0.78)))

            var near = Path()
            near.move(to: CGPoint(x: -size.width * 0.14, y: size.height))
            near.addLine(to: CGPoint(x: -size.width * 0.14, y: size.height * 0.67))
            near.addLine(to: CGPoint(x: size.width * 0.34, y: size.height * 0.45))
            near.addLine(to: CGPoint(x: size.width * 0.68, y: size.height * 0.69))
            near.addLine(to: CGPoint(x: size.width * 1.14, y: size.height * 0.55))
            near.addLine(to: CGPoint(x: size.width * 1.14, y: size.height))
            near.closeSubpath()
            context.fill(near, with: .color(AppColors.pageBase.opacity(0.96)))
        }
    }
}

private struct LoginRouteGlow: View {
    let highlightsFinish: Bool

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 8, y: size.height * 0.78))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.48, y: size.height * 0.48),
                    control1: CGPoint(x: size.width * 0.14, y: size.height * 0.66),
                    control2: CGPoint(x: size.width * 0.34, y: size.height * 0.62)
                )
                path.addCurve(
                    to: CGPoint(x: size.width - 8, y: size.height * 0.22),
                    control1: CGPoint(x: size.width * 0.64, y: size.height * 0.31),
                    control2: CGPoint(x: size.width * 0.82, y: size.height * 0.40)
                )
                context.stroke(path, with: .color(AppColors.interactionPrimary.opacity(0.28)), lineWidth: 10)
                context.stroke(path, with: .color(AppColors.interactionPrimary), lineWidth: 2.5)
                context.fill(
                    Path(ellipseIn: CGRect(x: 3, y: size.height * 0.78 - 5, width: 10, height: 10)),
                    with: .color(AppColors.interactionPrimary)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: size.width - 13, y: size.height * 0.22 - 5, width: 10, height: 10)),
                    with: .color(AppColors.interactionPrimary.opacity(highlightsFinish ? 1 : 0.25))
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
