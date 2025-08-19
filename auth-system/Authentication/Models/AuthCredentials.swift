import Foundation

// MARK: - 인증 자격증명
struct AuthCredentials {
    let email: String
    let password: String
}

// MARK: - 인증 결과
struct AuthResult {
    let user: User
    let token: String?
    let sessionId: String?
    let expiresAt: Date?
    let authType: AuthType
}

// MARK: - 사용자 모델
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let avatarURL: String?
    let provider: AuthProvider
    
    enum AuthProvider: String, Codable, CaseIterable {
        case email = "email"
        case google = "google"
        case github = "github"
        case apple = "apple"
    }
}

// MARK: - 인증 타입
enum AuthType: String, CaseIterable {
    case session = "session"
    case jwt = "jwt" 
    case oauth2 = "oauth2"
    
    var displayName: String {
        switch self {
        case .session: return "세션 방식"
        case .jwt: return "JWT 토큰"
        case .oauth2: return "OAuth2"
        }
    }
}

// MARK: - 인증 에러
enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError(Error)
    case tokenExpired
    case sessionExpired
    case oauth2Error(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "이메일 또는 비밀번호가 올바르지 않습니다."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        case .tokenExpired:
            return "토큰이 만료되었습니다. 다시 로그인해주세요."
        case .sessionExpired:
            return "세션이 만료되었습니다. 다시 로그인해주세요."
        case .oauth2Error(let message):
            return "OAuth2 오류: \(message)"
        case .unknown(let error):
            return "알 수 없는 오류: \(error.localizedDescription)"
        }
    }
}