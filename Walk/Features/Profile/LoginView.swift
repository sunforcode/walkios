import Lottie
import SwiftUI
import WalkData
import WalkDesignSystem

@MainActor
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: LoginViewModel
    @State private var didResolveAuthenticationFlow = false
    @State private var now = Date()
    let intent: PendingAuthIntent?
    let onAuthenticated: () -> Void
    let onCancel: () -> Void

    init(
        accountService: any AccountServicing,
        intent: PendingAuthIntent? = nil,
        onAuthenticated: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: LoginViewModel(
            accountService: accountService
        ))
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
        _viewModel = State(initialValue: viewModel)
        self.intent = intent
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
                    onChangePhone: viewModel.updatePhone,
                    onSendCode: { Task { await viewModel.sendVerificationCode() } },
                    onChangeCode: viewModel.updateCode,
                    onVerifyCode: { Task { await viewModel.login() } },
                    onResendCode: { Task { await viewModel.sendVerificationCode() } }
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
        viewModel.cancelPendingOperations()
        onCancel()
        dismiss()
    }

    /// AuthPanel 投影映射：手机号与验证码两个互斥阶段由 LoginViewModel.Phase 驱动；phone 阶段发送失败作为 operationError
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
            retryAvailableAt: viewModel.state.activeRetryAvailableAt(at: now),
            fieldError: fieldError,
            operationError: operationError,
            isLoading: viewModel.isSubmitting,
            isPrimaryEnabled: viewModel.phase == .phone ? viewModel.state.canSendCode(at: now) : viewModel.canLogin,
            isSecondaryEnabled: viewModel.state.canResend(at: now)
        )
    }

    private var authStage: AuthPanelStage {
        switch viewModel.phase {
        case .phone: .phone
        case .verificationCode: .code
        }
    }

    private var fieldError: String? {
        switch viewModel.phase {
        case .phone:
            return viewModel.state.phoneValidationError
        case .verificationCode:
            return viewModel.errorMessage
        }
    }

    private var operationError: String? {
        switch viewModel.phase {
        case .phone:
            return viewModel.errorMessage
        case .verificationCode:
            return nil
        }
    }

    /// 最近一个尚未到期的冷却时刻；View 只负责到期唤醒，不决定业务能力。
    private var nextCooldownDeadline: Date? {
        viewModel.state.nextCooldownDeadline(after: now)
    }

    private var contextualNote: String {
        if viewModel.phase == .verificationCode {
            return "完成验证后将继续刚才的任务。"
        }
        switch intent {
        case .trips:
            return "登录后查看你的当前与历史行程。"
        case .equipment:
            return "登录后管理个人装备与常用清单。"
        case .createTrip:
            return "登录后继续生成这条路线的个人行程。"
        case .profile:
            return "登录后返回“我的”，查看行程日历与个人资料。"
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
