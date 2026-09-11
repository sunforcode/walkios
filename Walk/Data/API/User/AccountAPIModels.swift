import Foundation

enum AccountAPI {
    struct SendVerificationCode: APIRequest {
        typealias Response = VerificationCodeResponse
        let method: APIHTTPMethod = .post
        let path = "/auth/verification-codes"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data
        let authenticationPolicy: APIAuthenticationPolicy = .none

        init(phone: String) throws {
            body = try JSONEncoder().encode(SendVerificationCodeBody(phone: phone))
        }
    }

    struct CreateSession: APIRequest {
        typealias Response = AuthSessionResponse
        let method: APIHTTPMethod = .post
        let path = "/auth/session"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data
        let authenticationPolicy: APIAuthenticationPolicy = .none

        init(verificationID: String, code: String) throws {
            body = try JSONEncoder().encode(CreateSessionBody(verificationId: verificationID, code: code))
        }
    }

    struct Current: APIRequest {
        typealias Response = AccountResponse
        let method: APIHTTPMethod = .get
        let path = "/account"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct UpdateProfile: APIRequest {
        typealias Response = ProfileResponse
        let method: APIHTTPMethod = .patch
        let path = "/account/profile"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(update: ProfileUpdate) throws {
            body = try JSONEncoder().encode(update)
        }
    }

    struct UploadAvatar: APIRequest {
        typealias Response = AvatarMediaResponse
        let method: APIHTTPMethod = .post
        let path = "/account/profile/avatar-media"
        let body: Data?
        let contentType: String?
        let responseEnvelope: APIResponseEnvelope = .data

        init(data: Data, contentType: String) {
            body = data
            self.contentType = contentType
        }
    }

    struct Logout: APIRequest {
        typealias Response = LogoutResponse
        let method: APIHTTPMethod = .delete
        let path = "/auth/session"
        let responseEnvelope: APIResponseEnvelope = .data
    }
}

private struct SendVerificationCodeBody: Encodable { let phone: String }
private struct CreateSessionBody: Encodable { let verificationId: String; let code: String }

struct VerificationCodeResponse: Codable, Equatable {
    let verificationId: String
    let expiresAt: Date
    let resendAvailableAt: Date
}

struct AuthSessionResponse: Codable, Equatable {
    let accessToken: String
    let tokenType: String
}

struct AccountResponse: Codable, Equatable {
    let account: AccountProjection
    let profile: ProfileProjection
}

struct AccountProjection: Codable, Equatable { let identity: String }
struct ProfileResponse: Codable, Equatable { let profile: ProfileProjection }

struct ProfileProjection: Codable, Equatable {
    let identity: String
    let maskedPhone: String
    let nickname: String?
    let avatar: String?
}

struct AvatarMediaResponse: Codable, Equatable { let mediaReference: String }
struct LogoutResponse: Codable, Equatable { let loggedOut: Bool }


struct ProfileUpdate: Encodable, Equatable {
    enum Field<Value: Encodable & Equatable>: Encodable, Equatable {
        case unchanged
        case value(Value)
        case clear

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .unchanged, .clear: try container.encodeNil()
            case .value(let value): try container.encode(value)
            }
        }
    }

    let nickname: Field<String>
    let avatar: Field<String>

    init(nickname: Field<String> = .unchanged, avatar: Field<String> = .unchanged) {
        self.nickname = nickname
        self.avatar = avatar
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if nickname != .unchanged { try container.encode(nickname, forKey: .nickname) }
        if avatar != .unchanged { try container.encode(avatar, forKey: .avatar) }
    }

    private enum CodingKeys: String, CodingKey { case nickname, avatar }
}
