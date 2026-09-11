import Foundation

public enum AccountAPI {
    public struct SendVerificationCode: APIRequest {
        public typealias Response = VerificationCodeResponse
        public let method: APIHTTPMethod = .post
        public let path = "/auth/verification-codes"
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data
        public let authenticationPolicy: APIAuthenticationPolicy = .none

        public init(phone: String) throws {
            body = try JSONEncoder().encode(SendVerificationCodeBody(phone: phone))
        }
    }

    public struct CreateSession: APIRequest {
        public typealias Response = AuthSessionResponse
        public let method: APIHTTPMethod = .post
        public let path = "/auth/session"
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data
        public let authenticationPolicy: APIAuthenticationPolicy = .none

        public init(verificationID: String, code: String) throws {
            body = try JSONEncoder().encode(CreateSessionBody(verificationId: verificationID, code: code))
        }
    }

    public struct Current: APIRequest {
        public typealias Response = AccountResponse
        public let method: APIHTTPMethod = .get
        public let path = "/account"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store


        public init() {}    }

    public struct UpdateProfile: APIRequest {
        public typealias Response = ProfileResponse
        public let method: APIHTTPMethod = .patch
        public let path = "/account/profile"
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(update: ProfileUpdate) throws {
            body = try JSONEncoder().encode(update)
        }
    }

    public struct UploadAvatar: APIRequest {
        public typealias Response = AvatarMediaResponse
        public let method: APIHTTPMethod = .post
        public let path = "/account/profile/avatar-media"
        public let body: Data?
        public let contentType: String?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(data: Data, contentType: String) {
            body = data
            self.contentType = contentType
        }
    }

    public struct Logout: APIRequest {
        public typealias Response = LogoutResponse
        public let method: APIHTTPMethod = .delete
        public let path = "/auth/session"
        public let responseEnvelope: APIResponseEnvelope = .data

        public init() {}
    }
}

private struct SendVerificationCodeBody: Encodable { public let phone: String }
private struct CreateSessionBody: Encodable { public let verificationId: String; let code: String }

public struct VerificationCodeResponse: Codable, Equatable {
     public let verificationId: String
     public let expiresAt: Date
     public let resendAvailableAt: Date

    public init(
        verificationId: String,
        expiresAt: Date,
        resendAvailableAt: Date
    ) {
        self.verificationId = verificationId
        self.expiresAt = expiresAt
        self.resendAvailableAt = resendAvailableAt
    }
}

public struct AuthSessionResponse: Codable, Equatable {
     public let accessToken: String
     public let tokenType: String

    public init(
        accessToken: String,
        tokenType: String
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
    }
}

public struct AccountResponse: Codable, Equatable {
     public let account: AccountProjection
     public let profile: ProfileProjection

    public init(
        account: AccountProjection,
        profile: ProfileProjection
    ) {
        self.account = account
        self.profile = profile
    }
}

public struct AccountProjection: Codable, Equatable { public let identity: String 
    public init(
        identity: String
    ) {
        self.identity = identity
    }
}
public struct ProfileResponse: Codable, Equatable { public let profile: ProfileProjection 
    public init(
        profile: ProfileProjection
    ) {
        self.profile = profile
    }
}

public struct ProfileProjection: Codable, Equatable {
     public let identity: String
     public let maskedPhone: String
     public let nickname: String?
     public let avatar: String?

    public init(
        identity: String,
        maskedPhone: String,
        nickname: String?,
        avatar: String?
    ) {
        self.identity = identity
        self.maskedPhone = maskedPhone
        self.nickname = nickname
        self.avatar = avatar
    }
}

public struct AvatarMediaResponse: Codable, Equatable { public let mediaReference: String 
    public init(
        mediaReference: String
    ) {
        self.mediaReference = mediaReference
    }
}
public struct LogoutResponse: Codable, Equatable { public let loggedOut: Bool 
    public init(
        loggedOut: Bool
    ) {
        self.loggedOut = loggedOut
    }
}


public struct ProfileUpdate: Encodable, Equatable {
    public enum Field<Value: Encodable & Equatable>: Encodable, Equatable {
        case unchanged
        case value(Value)
        case clear

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .unchanged, .clear: try container.encodeNil()
            case .value(let value): try container.encode(value)
            }
        }
    }

     public let nickname: Field<String>
     public let avatar: Field<String>

     public init(nickname: Field<String> = .unchanged, avatar: Field<String> = .unchanged) {
        self.nickname = nickname
        self.avatar = avatar
    }

     public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if nickname != .unchanged { try container.encode(nickname, forKey: .nickname) }
        if avatar != .unchanged { try container.encode(avatar, forKey: .avatar) }
    }

    private enum CodingKeys: String, CodingKey { case nickname, avatar }
}
