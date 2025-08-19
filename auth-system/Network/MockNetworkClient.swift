import Foundation

// MARK: - 학습용 Mock 네트워크 클라이언트
class MockNetworkClient: NetworkClient {
    
    // 가짜 사용자 데이터베이스
    private let mockUsers: [String: (password: String, user: User)] = [
        "test@example.com": (
            password: "password123",
            user: User(
                id: "user-1",
                email: "test@example.com",
                name: "테스트 사용자",
                avatarURL: nil,
                provider: .email
            )
        ),
        "admin@example.com": (
            password: "admin123",
            user: User(
                id: "admin-1", 
                email: "admin@example.com",
                name: "관리자",
                avatarURL: nil,
                provider: .email
            )
        )
    ]
    
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        headers: [String : String]?
    ) async throws -> T {
        
        // 네트워크 지연 시뮬레이션
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1초
        
        // 엔드포인트별 처리
        switch endpoint {
        case "/auth/login":
            return try handleLogin(body: body) as! T
            
        case "/auth/refresh":
            return try handleRefresh(headers: headers) as! T
            
        case "/auth/logout":
            return try handleLogout() as! T
            
        case "/auth/session":
            return try handleSessionCheck(headers: headers) as! T
            
        case "/oauth2/token":
            return try handleOAuth2Token(body: body) as! T
            
        default:
            throw NetworkError.invalidEndpoint
        }
    }
    
    // MARK: - Request Handlers
    
    private func handleLogin(body: Data?) throws -> APIResponse<LoginResponse> {
        guard let body = body,
              let loginRequest = try? JSONDecoder().decode(LoginRequest.self, from: body) else {
            throw NetworkError.invalidRequest
        }
        
        // 사용자 검증
        guard let userInfo = mockUsers[loginRequest.email],
              userInfo.password == loginRequest.password else {
            throw NetworkError.unauthorized
        }
        
        // 성공 응답
        let response = LoginResponse(
            user: userInfo.user,
            token: generateMockToken(),
            sessionId: generateMockSessionId(),
            expiresAt: Date().addingTimeInterval(3600).ISO8601Format()
        )
        
        return APIResponse(
            success: true,
            data: response,
            message: "로그인 성공",
            error: nil
        )
    }
    
    private func handleRefresh(headers: [String: String]?) throws -> APIResponse<LoginResponse> {
        // 토큰 검증 (간단히)
        guard let headers = headers,
              let authHeader = headers["Authorization"],
              authHeader.hasPrefix("Bearer ") else {
            throw NetworkError.unauthorized
        }
        
        // 새 토큰 발급
        let user = mockUsers["test@example.com"]!.user
        let response = LoginResponse(
            user: user,
            token: generateMockToken(),
            sessionId: nil,
            expiresAt: Date().addingTimeInterval(3600).ISO8601Format()
        )
        
        return APIResponse(
            success: true,
            data: response,
            message: "토큰 갱신 성공",
            error: nil
        )
    }
    
    private func handleLogout() throws -> APIResponse<EmptyResponse> {
        return APIResponse(
            success: true,
            data: EmptyResponse(),
            message: "로그아웃 성공",
            error: nil
        )
    }
    
    private func handleSessionCheck(headers: [String: String]?) throws -> APIResponse<User> {
        // 세션 검증
        guard let headers = headers,
              let sessionId = headers["Session-ID"],
              !sessionId.isEmpty else {
            throw NetworkError.unauthorized
        }
        
        let user = mockUsers["test@example.com"]!.user
        return APIResponse(
            success: true,
            data: user,
            message: "세션 유효",
            error: nil
        )
    }
    
    private func handleOAuth2Token(body: Data?) throws -> APIResponse<OAuth2TokenResponse> {
        // OAuth2 토큰 교환 시뮬레이션
        let response = OAuth2TokenResponse(
            accessToken: generateMockToken(),
            refreshToken: generateMockToken(),
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        
        return APIResponse(
            success: true,
            data: response,
            message: "OAuth2 토큰 발급 성공",
            error: nil
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateMockToken() -> String {
        return "mock_token_\(UUID().uuidString.prefix(8))"
    }
    
    private func generateMockSessionId() -> String {
        return "session_\(UUID().uuidString.prefix(8))"
    }
}

// MARK: - Response Models

struct EmptyResponse: Codable {}

struct OAuth2TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidEndpoint
    case invalidRequest
    case unauthorized
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "잘못된 엔드포인트"
        case .invalidRequest:
            return "잘못된 요청"
        case .unauthorized:
            return "인증 실패"
        case .serverError:
            return "서버 오류"
        }
    }
}