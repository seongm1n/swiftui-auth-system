import Foundation

// MARK: - 인증 서비스 프로토콜
protocol AuthenticationService {
    var authType: AuthType { get }
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    
    // 핵심 인증 메서드
    func login(credentials: AuthCredentials) async throws -> AuthResult
    func logout() async throws
    func refreshAuth() async throws -> AuthResult?
    
    // 상태 확인
    func validateCurrentAuth() async throws -> Bool
}

// MARK: - 토큰 저장소 프로토콜
protocol TokenStorage {
    func store(token: String, for key: String) throws
    func retrieve(for key: String) throws -> String?
    func delete(for key: String) throws
    func clear() throws
}

// MARK: - 네트워크 클라이언트 프로토콜
protocol NetworkClient {
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        headers: [String: String]?
    ) async throws -> T
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - API 응답 모델
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
    let error: String?
}

// MARK: - 로그인 요청/응답 모델
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let user: User
    let token: String?
    let sessionId: String?
    let expiresAt: String?
}

