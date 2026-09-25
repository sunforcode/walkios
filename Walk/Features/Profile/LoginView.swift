import Lottie
import SwiftUI
import WalkData
import WalkDesignSystem

@MainActor
final class LoginViewModel: ObservableObject {
    enum Phase: Equatable {
        case phone
        case verificationCode
        case confirmingFocus
        case focusError
    }

    @Published var phone = ""
    @Published var code = ""
    @Published var phase: Phase = .phone
    @Published var verificationID: String?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var resendAvailableAt: Date?
    @Published private(set) var retryAvailableAt: Date?
    @Published private(set) var account: AccountResponse?
    @Published private(set) var didAuthenticate = false
    @Published private(set) var confirmedFocusTripExists: Bool?
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var focusErrorMessage: String?

    private let sendCode: (String) async throws -> VerificationCodeResponse
    private let createSession: (String, String) async throws -> Void
    private let loadAccount: () async throws -> AccountResponse
    private let confirmFocusTrip: (() async throws -> Bool)?
    private var focusConfirmationGeneration = 0
    private var isAuthenticationCancelled = false

    init(
        accountService: any AccountServicing,
        confirmFocusTrip: (() async throws -> Bool)? = nil
    ) {
        self.sendCode = { try await accountService.sendVerificationCode(phone: $0) }
        self.createSession = { verificationID, code in
            _ = try await accountService.createSession(verificationID: verificationID, code: code)
        }
        self.loadAccount = { try await accountService.currentAccount() }
        self.confirmFocusTrip = confirmFocusTrip
    }

    init(
        sendCode: @escaping (String) async throws -> VerificationCodeResponse,
        createSession: @escaping (String, String) async throws -> Void,
        loadAccount: @escaping () async throws -> AccountResponse,
        confirmFocusTrip: (() async throws -> Bool)? = nil
    ) {
        self.sendCode = sendCode
        self.createSession = createSession
        self.loadAccount = loadAccount
        self.confirmFocusTrip = confirmFocusTrip
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
            && (retryAvailableAt.map { $0 <= Date() } ?? true)
    }

    var canLogin: Bool {
        verificationID != nil
            && code.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil
    }

    func sendVerificationCode() async {
        guard !isSubmitting else { return }
        guard let normalizedPhone = Self.normalizedPhone(phone) else {
            errorMessage = "请输入有效手机号"
            return
        }
        guard retryAvailableAt.map({ $0 <= Date() }) ?? true else { return }
        retryAvailableAt = nil
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let response = try await sendCode(normalizedPhone)
            verificationID = response.verificationId
            expiresAt = response.expiresAt
            resendAvailableAt = response.resendAvailableAt
            retryAvailableAt = nil
            phase = .verificationCode
        } catch {
            if let retryAt = Self.retryAvailableAt(for: error) {
                retryAvailableAt = retryAt
                errorMessage = nil
            } else {
                errorMessage = Self.message(for: error)
            }
        }
    }

    func login() async {
        guard !isSubmitting, let verificationID, canLogin else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await createSession(verificationID, code)
        } catch {
            guard !isAuthenticationCancelled, !Task.isCancelled else { return }
            errorMessage = Self.message(for: error)
            return
        }
        guard !isAuthenticationCancelled, !Task.isCancelled else { return }

        // account-access「认证成功承接原任务」：开启新行程意图在登录后先确认焦点行程，
        // 失败进入 focusError 提供重试，不误判为没有焦点行程。
        if let confirmFocusTrip {
            guard await runFocusTripConfirmation(confirmFocusTrip) else { return }
        }
        guard !isAuthenticationCancelled, !Task.isCancelled else { return }

        didAuthenticate = true
        account = try? await loadAccount()
    }

    func retryFocusTripConfirmation() async {
        guard !isAuthenticationCancelled,
              !isSubmitting,
              !didAuthenticate,
              let confirmFocusTrip else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        guard await runFocusTripConfirmation(confirmFocusTrip),
              !isAuthenticationCancelled,
              !Task.isCancelled else { return }
        didAuthenticate = true
        account = try? await loadAccount()
    }

    func cancelPendingOperations() {
        isAuthenticationCancelled = true
        focusConfirmationGeneration += 1
        confirmedFocusTripExists = nil
    }

    @discardableResult
    private func runFocusTripConfirmation(_ confirm: () async throws -> Bool) async -> Bool {
        let generation = focusConfirmationGeneration
        guard !isAuthenticationCancelled else { return false }
        phase = .confirmingFocus
        focusErrorMessage = nil
        do {
            let focusExists = try await confirm()
            guard !isAuthenticationCancelled,
                  !Task.isCancelled,
                  generation == focusConfirmationGeneration else { return false }
            confirmedFocusTripExists = focusExists
            return true
        } catch {
            guard !isAuthenticationCancelled,
                  !Task.isCancelled,
                  generation == focusConfirmationGeneration else { return false }
            focusErrorMessage = Self.message(for: error)
            phase = .focusError
            return false
        }
    }

    private static func retryAvailableAt(for error: Error) -> Date? {
        guard let apiError = error as? APIClientError,
              case .api(let code, _, _, let details) = apiError,
              code == "verification_send_throttled" else {
            return nil
        }
        return details?.retryAvailableAt
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: LoginViewModel
    @State private var didResolveAuthenticationFlow = false
    @State private var now = Date()
    let intent: PendingAuthIntent?
    let onConfirmedFocusTrip: (Bool) -> Void
    let onAuthenticated: () -> Void
    let onCancel: () -> Void

    init(
        accountService: any AccountServicing,
        intent: PendingAuthIntent? = nil,
        onConfirmFocusTrip: (() async throws -> Bool)? = nil,
        onConfirmedFocusTrip: @escaping (Bool) -> Void = { _ in },
        onAuthenticated: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(
            accountService: accountService,
            confirmFocusTrip: onConfirmFocusTrip
        ))
        self.intent = intent
        self.onConfirmedFocusTrip = onConfirmedFocusTrip
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
    }

    init(
        viewModel: LoginViewModel,
        intent: PendingAuthIntent? = nil,
        onConfirmedFocusTrip: @escaping (Bool) -> Void = { _ in },
        onAuthenticated: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.intent = intent
        self.onConfirmedFocusTrip = onConfirmedFocusTrip
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 背景层忽略键盘安全区：键盘升起只移动面板，不让场景随键盘逐帧重新布局。
                // 静态场景（模糊光斑、等高线、山脊、路线光效）合成为单层位图后再参与动画。
                LoginNightRidgeScene(phase: viewModel.phase)
                    .drawingGroup()
                    .ignoresSafeArea()
                    .ignoresSafeArea(.keyboard)

                if !reduceMotion {
                    LoginAmbientAnimation()
                        .ignoresSafeArea()
                        .ignoresSafeArea(.keyboard)
                }

                AuthPanel(
                    projection: authProjection,
                    onClose: cancelAuthentication,
                    onChangePhone: { viewModel.phone = $0 },
                    onSendCode: { Task { await viewModel.sendVerificationCode() } },
                    onChangeCode: { viewModel.code = $0 },
                    onVerifyCode: { Task { await viewModel.login() } },
                    onResendCode: { Task { await viewModel.sendVerificationCode() } },
                    onRetryFocusTrip: { Task { await viewModel.retryFocusTripConfirmation() } }
                )
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
        .onChange(of: viewModel.didAuthenticate) { authenticated in
            guard authenticated else { return }
            if let focusExists = viewModel.confirmedFocusTripExists {
                onConfirmedFocusTrip(focusExists)
            }
            didResolveAuthenticationFlow = true
            onAuthenticated()
        }
        .onDisappear {
            viewModel.cancelPendingOperations()
            if !didResolveAuthenticationFlow { onCancel() }
        }
        // 冷却状态只取决于「重发 / 重试可用时刻」是否已过。原先每秒刷新 now 会让整页
        // （场景、Lottie、面板）每秒重算一次并与弹出、键盘动画叠加造成卡顿；
        // 现在只在存在未到期冷却时，于最近的到期时刻刷新一次。
        .task(id: nextCooldownDeadline) {
            guard let deadline = nextCooldownDeadline else { return }
            let interval = deadline.timeIntervalSinceNow
            if interval > 0 {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000) + 50_000_000)
            }
            guard !Task.isCancelled else { return }
            now = Date()
        }
    }

    private func cancelAuthentication() {
        guard !didResolveAuthenticationFlow else { return }
        didResolveAuthenticationFlow = true
        onCancel()
        dismiss()
    }

    /// AuthPanel 投影映射：四互斥阶段由 LoginViewModel.Phase 驱动；phone 阶段发送失败作为 operationError
    /// 由组件以 ErrorView 呈现，code 阶段验证失败作为字段错误原位显示。
    private var authProjection: AuthPanelProjection {
        AuthPanelProjection(
            stage: authStage,
            sourceContext: contextualNote,
            phone: viewModel.phone,
            code: viewModel.code,
            verificationID: viewModel.verificationID,
            expiresAt: viewModel.expiresAt,
            resendAvailableAt: viewModel.resendAvailableAt,
            retryAvailableAt: activeRetryAvailableAt,
            fieldError: fieldError,
            operationError: operationError,
            isLoading: viewModel.isSubmitting,
            isPrimaryEnabled: viewModel.phase == .phone ? viewModel.canSendCode : viewModel.canLogin,
            isSecondaryEnabled: canResend
        )
    }

    private var authStage: AuthPanelStage {
        switch viewModel.phase {
        case .phone: .phone
        case .verificationCode: .code
        case .confirmingFocus: .confirmingFocus
        case .focusError: .focusError
        }
    }

    private var fieldError: String? {
        switch viewModel.phase {
        case .phone:
            return phoneValidationError
        case .verificationCode:
            return viewModel.errorMessage
        case .confirmingFocus, .focusError:
            return nil
        }
    }

    private var operationError: String? {
        switch viewModel.phase {
        case .phone:
            return viewModel.errorMessage
        case .focusError:
            return viewModel.focusErrorMessage
        case .verificationCode, .confirmingFocus:
            return nil
        }
    }

    private var phoneValidationError: String? {
        guard !viewModel.phone.isEmpty,
              LoginViewModel.normalizedPhone(viewModel.phone) == nil else {
            return nil
        }
        return "请输入有效手机号"
    }

    /// 最近一个尚未到期的冷却时刻；没有冷却时为 nil，页面不做任何定时刷新。
    private var nextCooldownDeadline: Date? {
        [viewModel.resendAvailableAt, viewModel.retryAvailableAt]
            .compactMap { $0 }
            .filter { $0 > now }
            .min()
    }

    private var activeRetryAvailableAt: Date? {
        guard let retryAt = viewModel.retryAvailableAt, retryAt > now else { return nil }
        return retryAt
    }

    private var remainingSeconds: Int {
        guard let availableAt = viewModel.resendAvailableAt else { return 0 }
        return max(0, Int(ceil(availableAt.timeIntervalSince(now))))
    }

    private var canResend: Bool {
        remainingSeconds == 0 && activeRetryAvailableAt == nil
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

/// 登录与个人设置页共用的极光呼吸装饰层（Lottie 循环）；仅装饰，不拦截交互。
/// 渲染与否由调用方根据 Reduce Motion 决定。
struct LoginAmbientAnimation: View {
    var body: some View {
        LottieView(animation: .named("LoginRidgeAmbient"))
            .looping()
            .playing()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct LoginNightRidgeScene: View {
    let phase: LoginViewModel.Phase

    var body: some View {
        ZStack(alignment: .topLeading) {
            NightRidgePaletteScene()

            LoginRouteGlow(highlightsFinish: phase == .verificationCode)
                .padding(.horizontal, 36)
                .padding(.top, 126)
                .frame(height: 412)

            VStack(alignment: .leading, spacing: 2) {
                Text("Walk")
                    .font(.ornament(15, weight: .black))
                    .tracking(2)
                    .foregroundStyle(AppColors.textPrimary)
                Text("ROUTE 01 · PERSONAL JOURNEY")
                    .font(.appCaption)
                    .tracking(1)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.leading, 24)
            .padding(.top, 60)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// 夜景山脊氛围底色：pageMiddle 底 + 薄荷光斑 + 等高线 + 双层山脊。
/// 登录页与个人设置页共用的生产实现；登录页在此之上叠加 logo 与路线光效。
struct NightRidgePaletteScene: View {
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
