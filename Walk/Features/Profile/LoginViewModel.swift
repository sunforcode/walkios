import Foundation
import Observation
import WalkData

@MainActor
@Observable
final class LoginViewModel {
    typealias Phase = LoginState.Phase

    private(set) var state = LoginState()

    var phone: String { state.phone }
    var code: String { state.code }
    var phase: Phase { state.phase }
    var verificationID: String? { state.verificationID }
    var expiresAt: Date? { state.expiresAt }
    var resendAvailableAt: Date? { state.resendAvailableAt }
    var retryAvailableAt: Date? { state.retryAvailableAt }
    var account: AccountResponse? { state.account }
    var didAuthenticate: Bool { state.didAuthenticate }
    var isSubmitting: Bool { state.isSubmitting }
    var errorMessage: String? { state.errorMessage }
    var canSendCode: Bool { !isAuthenticationCancelled && state.canSendCode(at: Date()) }
    var canLogin: Bool { !isAuthenticationCancelled && state.canLogin }

    private let sendCode: (String) async throws -> VerificationCodeResponse
    private let createSession: (String, String) async throws -> Void
    private let loadAccount: () async throws -> AccountResponse
    private var operationGeneration = 0
    private var isAuthenticationCancelled = false

    init(
        accountService: any AccountServicing
    ) {
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
        LoginState.normalizedPhone(raw)
    }

    func updatePhone(_ phone: String) {
        guard !isAuthenticationCancelled, state.phase == .phone, !isSubmitting else { return }
        state.phone = phone
        state.errorMessage = nil
    }

    func updateCode(_ code: String) {
        guard !isAuthenticationCancelled, !isSubmitting, !didAuthenticate,
              phase == .phone || phase == .verificationCode else { return }
        state.code = code
        state.errorMessage = nil
    }

    func sendVerificationCode() async {
        guard !isAuthenticationCancelled, !Task.isCancelled, !isSubmitting,
              phase == .phone || phase == .verificationCode else { return }
        guard let normalizedPhone = Self.normalizedPhone(phone) else {
            state.errorMessage = "请输入有效手机号"
            return
        }
        guard canSendCode else { return }
        let generation = beginOperation()
        state.retryAvailableAt = nil
        state.errorMessage = nil
        defer { finishOperation(generation) }
        do {
            let response = try await sendCode(normalizedPhone)
            guard acceptsResult(generation) else { return }
            state.verificationID = response.verificationId
            state.expiresAt = response.expiresAt
            state.resendAvailableAt = response.resendAvailableAt
            state.retryAvailableAt = nil
            state.phase = .verificationCode
        } catch {
            guard acceptsResult(generation), !Self.isCancellation(error) else { return }
            if let retryAt = Self.retryAvailableAt(for: error) {
                state.retryAvailableAt = retryAt
                state.errorMessage = nil
            } else {
                state.errorMessage = Self.message(for: error)
            }
        }
    }

    func login() async {
        guard !Task.isCancelled, canLogin, let verificationID else { return }
        let generation = beginOperation()
        state.errorMessage = nil
        defer { finishOperation(generation) }
        do {
            try await createSession(verificationID, code)
        } catch {
            guard acceptsResult(generation), !Self.isCancellation(error) else { return }
            state.errorMessage = Self.message(for: error)
            return
        }
        guard acceptsResult(generation) else { return }

        await publishAuthenticationAndLoadAccount(generation)
    }

    func cancelPendingOperations() {
        isAuthenticationCancelled = true
        operationGeneration += 1
        state.isSubmitting = false
    }

    private func publishAuthenticationAndLoadAccount(_ generation: Int) async {
        guard acceptsResult(generation) else { return }
        // 账号投影为可选回填，不能阻塞认证完成；退出页面后不再接收其迟到结果。
        state.didAuthenticate = true
        do {
            let account = try await loadAccount()
            guard acceptsResult(generation) else { return }
            state.account = account
        } catch {
            // 账号读取失败（包括取消）不撤销已成功的认证，也不转为验证码错误。
        }
    }

    private func beginOperation() -> Int {
        operationGeneration += 1
        state.isSubmitting = true
        return operationGeneration
    }

    private func finishOperation(_ generation: Int) {
        if operationGeneration == generation { state.isSubmitting = false }
    }

    private func acceptsResult(_ generation: Int) -> Bool {
        !isAuthenticationCancelled && !Task.isCancelled && operationGeneration == generation
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError { return true }
        if let apiError = error as? APIClientError, case .transport(.cancelled) = apiError { return true }
        return false
    }

    private static func retryAvailableAt(for error: Error) -> Date? {
        guard let apiError = error as? APIClientError,
              case .api(let code, _, _, let details) = apiError,
              code == "verification_send_throttled" else { return nil }
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
