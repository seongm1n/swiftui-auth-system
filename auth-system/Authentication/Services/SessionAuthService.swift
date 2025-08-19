import Foundation

// MARK: - 세션 기반 인증 서비스
class SessionAuthService: AuthenticationService {
    
    // MARK: - Properties
    let authType: AuthType = .session
    private let tokenStorage: TokenStorage
    private let networkClient: NetworkClient
    
    private var _currentUser: User?
    private var sessionId: String?
    
    var isAuthenticated: Bool {
        return _currentUser != nil && sessionId != nil
    }
    
    var currentUser: User? {
        return _currentUser
    }
    
    // MARK: - Initialization
    init(tokenStorage: TokenStorage, networkClient: NetworkClient) {
        self.tokenStorage = tokenStorage
        self.networkClient = networkClient
        
        // 앱 시작시 기존 세션 복원 시도
        Task {
            await restoreSession()
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
        
        // 세션 정보 저장
        if let sessionId = loginData.sessionId {
            try tokenStorage.store(token: sessionId, for: "session_id")
            self.sessionId = sessionId
        }
        
        // 사용자 정보 저장
        let userData = try JSONEncoder().encode(loginData.user)
        try tokenStorage.store(token: String(data: userData, encoding: .utf8)!, for: "current_user")
        self._currentUser = loginData.user
        
        // 만료 시간 저장 (옵션)
        if let expiresAt = loginData.expiresAt {
            try tokenStorage.store(token: expiresAt, for: "session_expires")
        }
        
        return AuthResult(
            user: loginData.user,
            token: nil, // 세션 방식에서는 토큰 대신 세션 ID 사용
            sessionId: sessionId,
            expiresAt: parseExpirationDate(loginData.expiresAt),
            authType: .session
        )
    }
    
    func logout() async throws {
        // 서버에 로그아웃 요청
        var headers: [String: String] = [:]
        if let sessionId = sessionId {
            headers["Session-ID"] = sessionId
        }
        
        let _: APIResponse<EmptyResponse> = try await networkClient.request(
            endpoint: "/auth/logout",
            method: .POST,
            body: nil,
            headers: headers
        )
        
        // 로컬 세션 정보 삭제
        try clearLocalSession()
    }
    
    func refreshAuth() async throws -> AuthResult? {
        guard let sessionId = sessionId else {
            throw AuthError.sessionExpired
        }
        
        // 세션 유효성 확인
        let response: APIResponse<User> = try await networkClient.request(
            endpoint: "/auth/session",
            method: .GET,
            body: nil,
            headers: ["Session-ID": sessionId]
        )
        
        guard response.success, let user = response.data else {
            // 세션이 만료됨
            try clearLocalSession()
            throw AuthError.sessionExpired
        }
        
        // 사용자 정보 업데이트
        self._currentUser = user
        let userData = try JSONEncoder().encode(user)
        try tokenStorage.store(token: String(data: userData, encoding: .utf8)!, for: "current_user")
        
        return AuthResult(
            user: user,
            token: nil,
            sessionId: sessionId,
            expiresAt: nil,
            authType: .session
        )
    }
    
    func validateCurrentAuth() async throws -> Bool {
        guard sessionId != nil else {
            return false
        }
        
        do {
            _ = try await refreshAuth()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func restoreSession() async {
        do {
            // 저장된 세션 ID 복원
            self.sessionId = try tokenStorage.retrieve(for: "session_id")
            
            // 저장된 사용자 정보 복원
            if let userDataString = try tokenStorage.retrieve(for: "current_user"),
               let userData = userDataString.data(using: .utf8) {
                self._currentUser = try JSONDecoder().decode(User.self, from: userData)
            }
            
            // 세션 유효성 확인
            if sessionId != nil {
                _ = try await validateCurrentAuth()
            }
        } catch {
            // 세션 복원 실패시 로컬 데이터 정리
            try? clearLocalSession()
        }
    }
    
    private func clearLocalSession() throws {
        self._currentUser = nil
        self.sessionId = nil
        
        try tokenStorage.delete(for: "session_id")
        try tokenStorage.delete(for: "current_user") 
        try tokenStorage.delete(for: "session_expires")
    }
    
    private func parseExpirationDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}