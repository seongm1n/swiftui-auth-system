import Foundation
import SwiftUI

// MARK: - 의존성 주입 컨테이너
@Observable
class AuthContainer {
    // MARK: - Properties
    private var _currentAuthService: AuthenticationService
    private(set) var tokenStorage: TokenStorage
    private(set) var networkClient: NetworkClient
    private let authServiceFactory: AuthServiceFactory
    
    var currentAuthService: AuthenticationService {
        get { _currentAuthService }
        set { _currentAuthService = newValue }
    }
    
    var currentAuthType: AuthType {
        currentAuthService.authType
    }
    
    @ObservationTracked
    var isAuthenticated: Bool {
        currentAuthService.isAuthenticated
    }
    
    var currentUser: User? {
        currentAuthService.currentUser
    }
    
    // MARK: - Initialization
    init(tokenStorage: TokenStorage, networkClient: NetworkClient, authServiceFactory: AuthServiceFactory) {
        self.tokenStorage = tokenStorage
        self.networkClient = networkClient
        self.authServiceFactory = authServiceFactory
        
        // 기본 인증 서비스 (JWT)
        self._currentAuthService = authServiceFactory.createService(for: .jwt)
    }
    
    // MARK: - Builder Pattern
    static func build() -> AuthContainer {
        let tokenStorage = KeychainTokenStorage()
        let networkClient = MockNetworkClient()
        let authServiceFactory = DefaultAuthServiceFactory(
            tokenStorage: tokenStorage,
            networkClient: networkClient
        )
        
        return AuthContainer(
            tokenStorage: tokenStorage,
            networkClient: networkClient,
            authServiceFactory: authServiceFactory
        )
    }
    
    // MARK: - 인증 방식 교체
    func switchAuthType(_ authType: AuthType) {
        // 기존 인증 상태 로그아웃
        Task {
            try? await currentAuthService.logout()
        }
        
        // 팩토리를 통한 새로운 인증 서비스 생성
        self.currentAuthService = authServiceFactory.createService(for: authType)
    }
}

// MARK: - Auth Service Factory Protocol
protocol AuthServiceFactory {
    func createService(for authType: AuthType) -> AuthenticationService
}

// MARK: - Default Auth Service Factory
class DefaultAuthServiceFactory: AuthServiceFactory {
    private let tokenStorage: TokenStorage
    private let networkClient: NetworkClient
    
    init(tokenStorage: TokenStorage, networkClient: NetworkClient) {
        self.tokenStorage = tokenStorage
        self.networkClient = networkClient
    }
    
    func createService(for authType: AuthType) -> AuthenticationService {
        switch authType {
        case .session:
            return SessionAuthService(
                tokenStorage: tokenStorage,
                networkClient: networkClient
            )
        case .jwt:
            return JWTAuthService(
                tokenStorage: tokenStorage,
                networkClient: networkClient
            )
        case .oauth2:
            return OAuth2AuthService(
                tokenStorage: tokenStorage,
                networkClient: networkClient
            )
        }
    }
}

// MARK: - SwiftUI Environment
extension AuthContainer {
    static let shared = AuthContainer.build()
}

// MARK: - Environment Key
private struct AuthContainerKey: EnvironmentKey {
    static let defaultValue = AuthContainer.shared
}

extension EnvironmentValues {
    var authContainer: AuthContainer {
        get { self[AuthContainerKey.self] }
        set { self[AuthContainerKey.self] = newValue }
    }
}