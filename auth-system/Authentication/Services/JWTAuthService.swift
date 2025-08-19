import Foundation

// MARK: - JWT 토큰 기반 인증 서비스
class JWTAuthService: AuthenticationService {
    
    // MARK: - Properties
    let authType: AuthType = .jwt
    private let tokenStorage: TokenStorage
    private let networkClient: NetworkClient
    
    private var _currentUser: User?
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiresAt: Date?
    
    var isAuthenticated: Bool {
        guard let token = accessToken, let expiresAt = tokenExpiresAt else {
            return false
        }
        return Date() < expiresAt
    }
    
    var currentUser: User? {
        return _currentUser
    }
    
    // MARK: - Initialization
    init(tokenStorage: TokenStorage, networkClient: NetworkClient) {
        self.tokenStorage = tokenStorage
        self.networkClient = networkClient
        
        // 앱 시작시 기존 토큰 복원 시도
        Task {
            await restoreTokens()
        }
    }
    
    // MARK: - AuthenticationService Protocol
    
    func login(credentials: AuthCredentials) async throws -> AuthResult {
        // 로그인 요청 준비
        let loginRequest = LoginRequest(
            email: credentials.email,
            password: credentials.password
        )
        
        let requestData = try JSONEncoder().encode(loginRequest)
        
        // 서버에 로그인 요청
        let response: APIResponse<LoginResponse> = try await networkClient.request(
            endpoint: "/auth/login",
            method: .POST,
            body: requestData,
            headers: ["Content-Type": "application/json"]
        )
        
        guard response.success, let loginData = response.data else {
            throw AuthError.invalidCredentials
        }
        
        // 사용자 정보 먼저 설정 (즉시 상태 업데이트)
        self._currentUser = loginData.user
        
        // JWT 토큰 저장
        if let token = loginData.token {
            try await storeTokens(
                accessToken: token,
                refreshToken: generateRefreshToken(), // Mock refresh token
                expiresAt: parseExpirationDate(loginData.expiresAt)
            )
        }
        
        // 사용자 정보 영구 저장
        let userData = try JSONEncoder().encode(loginData.user)
        try tokenStorage.store(token: String(data: userData, encoding: .utf8)!, for: "current_user")
        
        return AuthResult(
            user: loginData.user,
            token: loginData.token,
            sessionId: nil,
            expiresAt: parseExpirationDate(loginData.expiresAt),
            authType: .jwt
        )
    }
    
    func logout() async throws {
        // 서버에 로그아웃 요청 (토큰 무효화)
        var headers: [String: String] = [:]
        if let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        let _: APIResponse<EmptyResponse> = try await networkClient.request(
            endpoint: "/auth/logout",
            method: .POST,
            body: nil,
            headers: headers
        )
        
        // 로컬 토큰 정보 삭제
        try clearLocalTokens()
    }
    
    func refreshAuth() async throws -> AuthResult? {
        guard let refreshToken = refreshToken else {
            throw AuthError.tokenExpired
        }
        
        // 토큰 갱신 요청
        let response: APIResponse<LoginResponse> = try await networkClient.request(
            endpoint: "/auth/refresh",
            method: .POST,
            body: nil,
            headers: [
                "Authorization": "Bearer \(refreshToken)",
                "Content-Type": "application/json"
            ]
        )
        
        guard response.success, let refreshData = response.data else {
            // 리프레시 토큰도 만료됨
            try clearLocalTokens()
            throw AuthError.tokenExpired
        }
        
        // 새 토큰 저장
        if let newToken = refreshData.token {
            try await storeTokens(
                accessToken: newToken,
                refreshToken: generateRefreshToken(),
                expiresAt: parseExpirationDate(refreshData.expiresAt)
            )
        }
        
        // 사용자 정보 업데이트
        self._currentUser = refreshData.user
        let userData = try JSONEncoder().encode(refreshData.user)
        try tokenStorage.store(token: String(data: userData, encoding: .utf8)!, for: "current_user")
        
        return AuthResult(
            user: refreshData.user,
            token: refreshData.token,
            sessionId: nil,
            expiresAt: parseExpirationDate(refreshData.expiresAt),
            authType: .jwt
        )
    }
    
    func validateCurrentAuth() async throws -> Bool {
        // 토큰 만료 확인
        if !isAuthenticated {
            // 자동 토큰 갱신 시도
            do {
                _ = try await refreshAuth()
                return true
            } catch {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func restoreTokens() async {
        do {
            // 저장된 토큰들 복원
            self.accessToken = try tokenStorage.retrieve(for: "access_token")
            self.refreshToken = try tokenStorage.retrieve(for: "refresh_token")
            
            // 만료 시간 복원
            if let expiresString = try tokenStorage.retrieve(for: "token_expires") {
                let formatter = ISO8601DateFormatter()
                self.tokenExpiresAt = formatter.date(from: expiresString)
            }
            
            // 저장된 사용자 정보 복원
            if let userDataString = try tokenStorage.retrieve(for: "current_user"),
               let userData = userDataString.data(using: .utf8) {
                self._currentUser = try JSONDecoder().decode(User.self, from: userData)
            }
            
            // 토큰 유효성 확인
            if accessToken != nil {
                _ = try await validateCurrentAuth()
            }
        } catch {
            // 토큰 복원 실패시 로컬 데이터 정리
            try? clearLocalTokens()
        }
    }
    
    private func storeTokens(accessToken: String, refreshToken: String, expiresAt: Date?) async throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = expiresAt
        
        try tokenStorage.store(token: accessToken, for: "access_token")
        try tokenStorage.store(token: refreshToken, for: "refresh_token")
        
        if let expiresAt = expiresAt {
            let formatter = ISO8601DateFormatter()
            try tokenStorage.store(token: formatter.string(from: expiresAt), for: "token_expires")
        }
    }
    
    private func clearLocalTokens() throws {
        self._currentUser = nil
        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpiresAt = nil
        
        try tokenStorage.delete(for: "access_token")
        try tokenStorage.delete(for: "refresh_token")
        try tokenStorage.delete(for: "token_expires")
        try tokenStorage.delete(for: "current_user")
    }
    
    private func parseExpirationDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func generateRefreshToken() -> String {
        return "refresh_token_\(UUID().uuidString)"
    }
    
    // MARK: - JWT Token Utils (학습용 간단 구현)
    
    private func decodeJWT(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else { return nil }
        
        // Payload 디코딩 (실제로는 base64url 디코딩 필요)
        let payload = segments[1]
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
    
    private func isTokenExpired(_ token: String) -> Bool {
        guard let payload = decodeJWT(token),
              let exp = payload["exp"] as? TimeInterval else {
            return true
        }
        
        return Date().timeIntervalSince1970 >= exp
    }
}