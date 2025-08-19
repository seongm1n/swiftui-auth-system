import Foundation
import AuthenticationServices

// MARK: - OAuth2 기반 인증 서비스
class OAuth2AuthService: NSObject, AuthenticationService {
    
    // MARK: - Properties
    let authType: AuthType = .oauth2
    private let tokenStorage: TokenStorage
    private let networkClient: NetworkClient
    
    private var _currentUser: User?
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiresAt: Date?
    
    // OAuth2 설정
    private let clientId = "mock_client_id"
    private let redirectURI = "authsystem://oauth/callback"
    private let scope = "openid profile email"
    
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
    override init() {
        self.tokenStorage = KeychainTokenStorage()
        self.networkClient = MockNetworkClient()
        super.init()
        
        // 앱 시작시 기존 토큰 복원 시도
        Task {
            await restoreTokens()
        }
    }
    
    init(tokenStorage: TokenStorage, networkClient: NetworkClient) {
        self.tokenStorage = tokenStorage
        self.networkClient = networkClient
        super.init()
        
        // 앱 시작시 기존 토큰 복원 시도
        Task {
            await restoreTokens()
        }
    }
    
    // MARK: - AuthenticationService Protocol
    
    func login(credentials: AuthCredentials) async throws -> AuthResult {
        // OAuth2는 일반적으로 credentials를 직접 사용하지 않고 브라우저 플로우를 사용
        // 여기서는 학습용으로 간단한 시뮬레이션을 구현
        
        return try await performOAuth2Flow()
    }
    
    func logout() async throws {
        // 토큰 취소 요청 (옵션)
        if let token = accessToken {
            // 실제로는 OAuth2 제공자의 revoke 엔드포인트를 호출
            try await revokeToken(token)
        }
        
        // 로컬 토큰 정보 삭제
        try clearLocalTokens()
    }
    
    func refreshAuth() async throws -> AuthResult? {
        guard let refreshToken = refreshToken else {
            throw AuthError.tokenExpired
        }
        
        // OAuth2 토큰 갱신 요청
        let tokenRequest = OAuth2RefreshRequest(
            grantType: "refresh_token",
            refreshToken: refreshToken,
            clientId: clientId
        )
        
        let requestData = try JSONEncoder().encode(tokenRequest)
        
        let response: APIResponse<OAuth2TokenResponse> = try await networkClient.request(
            endpoint: "/oauth2/token",
            method: .POST,
            body: requestData,
            headers: ["Content-Type": "application/x-www-form-urlencoded"]
        )
        
        guard response.success, let tokenData = response.data else {
            try clearLocalTokens()
            throw AuthError.tokenExpired
        }
        
        // 새 토큰 저장
        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenData.expiresIn))
        try await storeTokens(
            accessToken: tokenData.accessToken,
            refreshToken: tokenData.refreshToken,
            expiresAt: expiresAt
        )
        
        // 사용자 정보 조회 (액세스 토큰으로)
        let user = try await fetchUserInfo(accessToken: tokenData.accessToken)
        self._currentUser = user
        
        let userData = try JSONEncoder().encode(user)
        try tokenStorage.store(token: String(data: userData, encoding: .utf8)!, for: "current_user")
        
        return AuthResult(
            user: user,
            token: tokenData.accessToken,
            sessionId: nil,
            expiresAt: expiresAt,
            authType: .oauth2
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
    
    // MARK: - OAuth2 Specific Methods
    
    private func performOAuth2Flow() async throws -> AuthResult {
        // 실제 OAuth2 Authorization Code Flow 시뮬레이션
        
        // 1. Authorization Code 생성 (실제로는 브라우저에서 사용자 승인 후 받음)
        let authorizationCode = generateMockAuthorizationCode()
        
        // 2. Authorization Code를 Access Token으로 교환
        let tokenRequest = OAuth2TokenRequest(
            grantType: "authorization_code",
            code: authorizationCode,
            redirectURI: redirectURI,
            clientId: clientId
        )
        
        let requestData = try JSONEncoder().encode(tokenRequest)
        
        let response: APIResponse<OAuth2TokenResponse> = try await networkClient.request(
            endpoint: "/oauth2/token",
            method: .POST,
            body: requestData,
            headers: ["Content-Type": "application/x-www-form-urlencoded"]
        )
        
        guard response.success, let tokenData = response.data else {
            throw AuthError.oauth2Error("토큰 교환 실패")
        }
        
        // 3. 토큰 저장
        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenData.expiresIn))
        try await storeTokens(
            accessToken: tokenData.accessToken,
            refreshToken: tokenData.refreshToken,
            expiresAt: expiresAt
        )
        
        // 4. 사용자 정보 조회
        let user = try await fetchUserInfo(accessToken: tokenData.accessToken)
        self._currentUser = user
        
        let userData = try JSONEncoder().encode(user)
        try tokenStorage.store(token: String(data: userData, encoding: .utf8)!, for: "current_user")
        
        return AuthResult(
            user: user,
            token: tokenData.accessToken,
            sessionId: nil,
            expiresAt: expiresAt,
            authType: .oauth2
        )
    }
    
    private func fetchUserInfo(accessToken: String) async throws -> User {
        // OAuth2 제공자의 UserInfo 엔드포인트에서 사용자 정보 조회
        // 여기서는 Mock 데이터 반환
        
        return User(
            id: "oauth2-user-1",
            email: "oauth2user@example.com",
            name: "OAuth2 사용자",
            avatarURL: "https://example.com/avatar.jpg",
            provider: .google // 예시로 Google 사용
        )
    }
    
    private func revokeToken(_ token: String) async throws {
        // OAuth2 제공자의 토큰 취소 엔드포인트 호출
        // 실제 구현에서는 제공자별로 다른 엔드포인트 사용
        
        let revokeRequest = OAuth2RevokeRequest(
            token: token,
            clientId: clientId
        )
        
        let requestData = try JSONEncoder().encode(revokeRequest)
        
        let _: APIResponse<EmptyResponse> = try await networkClient.request(
            endpoint: "/oauth2/revoke",
            method: .POST,
            body: requestData,
            headers: ["Content-Type": "application/x-www-form-urlencoded"]
        )
    }
    
    // MARK: - Private Methods
    
    private func restoreTokens() async {
        do {
            // 저장된 토큰들 복원
            self.accessToken = try tokenStorage.retrieve(for: "oauth2_access_token")
            self.refreshToken = try tokenStorage.retrieve(for: "oauth2_refresh_token")
            
            // 만료 시간 복원
            if let expiresString = try tokenStorage.retrieve(for: "oauth2_token_expires") {
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
    
    private func storeTokens(accessToken: String, refreshToken: String, expiresAt: Date) async throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = expiresAt
        
        try tokenStorage.store(token: accessToken, for: "oauth2_access_token")
        try tokenStorage.store(token: refreshToken, for: "oauth2_refresh_token")
        
        let formatter = ISO8601DateFormatter()
        try tokenStorage.store(token: formatter.string(from: expiresAt), for: "oauth2_token_expires")
    }
    
    private func clearLocalTokens() throws {
        self._currentUser = nil
        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpiresAt = nil
        
        try tokenStorage.delete(for: "oauth2_access_token")
        try tokenStorage.delete(for: "oauth2_refresh_token")
        try tokenStorage.delete(for: "oauth2_token_expires")
        try tokenStorage.delete(for: "current_user")
    }
    
    private func generateMockAuthorizationCode() -> String {
        return "auth_code_\(UUID().uuidString.prefix(16))"
    }
}

// MARK: - OAuth2 Request Models

struct OAuth2TokenRequest: Codable {
    let grantType: String
    let code: String
    let redirectURI: String
    let clientId: String
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectURI = "redirect_uri"
        case clientId = "client_id"
    }
}

struct OAuth2RefreshRequest: Codable {
    let grantType: String
    let refreshToken: String
    let clientId: String
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
        case clientId = "client_id"
    }
}

struct OAuth2RevokeRequest: Codable {
    let token: String
    let clientId: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case clientId = "client_id"
    }
}