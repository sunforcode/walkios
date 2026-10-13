import Foundation
import WalkData

struct LoginState {
    enum Phase: Equatable {
        case phone
        case verificationCode
    }

    var phone = ""
    var code = ""
    var phase: Phase = .phone
    var verificationID: String?
    var expiresAt: Date?
    var resendAvailableAt: Date?
    var retryAvailableAt: Date?
    var account: AccountResponse?
    var didAuthenticate = false
    var isSubmitting = false
    var errorMessage: String?

    static func normalizedPhone(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.range(of: #"^\+[1-9][0-9]{1,14}$"#, options: .regularExpression) != nil
            ? trimmed : nil
    }

    var phoneValidationError: String? {
        !phone.isEmpty && Self.normalizedPhone(phone) == nil ? "请输入有效手机号" : nil
    }

    var canLogin: Bool {
        phase == .verificationCode && !isSubmitting && !didAuthenticate
            && verificationID != nil
            && code.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil
    }

    func canSendCode(at now: Date) -> Bool {
        (phase == .phone || phase == .verificationCode)
            && Self.normalizedPhone(phone) != nil && canResend(at: now)
    }

    func canResend(at now: Date) -> Bool {
        !isSubmitting && !didAuthenticate
            && (resendAvailableAt.map { $0 <= now } ?? true)
            && activeRetryAvailableAt(at: now) == nil
    }

    func activeRetryAvailableAt(at now: Date) -> Date? {
        guard let retryAvailableAt, retryAvailableAt > now else { return nil }
        return retryAvailableAt
    }

    func nextCooldownDeadline(after now: Date) -> Date? {
        [resendAvailableAt, retryAvailableAt].compactMap { $0 }.filter { $0 > now }.min()
    }
}
