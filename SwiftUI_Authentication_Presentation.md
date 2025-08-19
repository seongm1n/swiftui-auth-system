# SwiftUI 인증 시스템 발표 스크립트

## 🎯 발표 개요 (1분)

안녕하세요. 오늘은 **SwiftUI를 활용한 종합적인 인증 시스템**에 대해 발표하겠습니다.

현대 앱 개발에서 인증은 필수 요소입니다. 하지만 **세션, JWT, OAuth2** 등 다양한 방식이 있어 어떤 것을 선택할지 고민이 되죠. 

오늘 발표에서는 **각 인증 방식의 특징과 장단점**을 실제 구현을 통해 비교 분석하고, **SwiftUI의 @Observable과 의존성 주입**을 활용한 확장 가능한 아키텍처를 소개하겠습니다.

---

## 🏗️ 아키텍처 설계 (2분)

### 핵심 설계 원칙

먼저 **확장 가능하고 테스트 가능한** 아키텍처를 설계했습니다.

```swift
protocol AuthenticationService {
    var authType: AuthType { get }
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    
    func login(credentials: AuthCredentials) async throws -> AuthResult
    func logout() async throws
    func refreshAuth() async throws -> AuthResult?
}
```

**프로토콜 기반 설계**로 각 인증 방식을 추상화하고, **의존성 주입 컨테이너**로 런타임에 인증 방식을 교체할 수 있게 했습니다.

### SwiftUI 통합

```swift
@Observable
class AuthContainer {
    private var _currentAuthService: AuthenticationService
    
    var isAuthenticated: Bool {
        currentAuthService.isAuthenticated
    }
}
```

**@Observable**을 활용해 인증 상태 변경이 UI에 즉시 반영되도록 구현했습니다.

---

## 🔐 세션 기반 인증 (3분)

### 특징 및 작동 원리

**세션 기반 인증**은 전통적인 웹 방식입니다.

```swift
class SessionAuthService: AuthenticationService {
    var isAuthenticated: Bool {
        sessionId != nil && sessionExpiresAt.map { Date() < $0 } ?? false
    }
}
```

### 🔥 장점
- **서버 완전 제어**: 언제든 세션을 무효화 가능
- **보안성**: 클라이언트에 민감한 정보 저장하지 않음
- **간단한 구현**: 쿠키 기반으로 자동 전송

### ❄️ 단점
- **서버 리소스**: 모든 세션을 서버 메모리/DB에 저장
- **확장성 제한**: 로드밸런싱 시 세션 공유 문제
- **모바일 비친화적**: 쿠키 관리의 복잡성

### 💡 적용 사례
- **관리자 페이지**: 즉시 접근 제어가 중요한 경우
- **은행/금융**: 높은 보안이 요구되는 서비스
- **사내 시스템**: 사용자 수가 제한적인 환경

---

## 🎫 JWT 토큰 인증 (3분)

### 특징 및 작동 원리

**JWT(JSON Web Token)**는 **Stateless** 방식입니다.

```swift
class JWTAuthService: AuthenticationService {
    var isAuthenticated: Bool {
        guard let token = accessToken, let expiresAt = tokenExpiresAt else {
            return false
        }
        return Date() < expiresAt
    }
}
```

### 🚀 장점
- **확장성**: 서버에 상태 저장 없이 수평 확장 용이
- **성능**: 매 요청마다 DB 조회 불필요
- **디커플링**: 인증 서버와 리소스 서버 분리 가능
- **모바일 친화적**: 토큰 기반으로 관리 단순

### ⚠️ 단점
- **토큰 크기**: 쿠키보다 큰 데이터 전송
- **즉시 무효화 어려움**: 토큰 만료까지 유효
- **보안 위험**: 클라이언트 저장으로 인한 XSS 취약점

### 🔄 핵심 구현: Refresh Token

```swift
func refreshAuth() async throws -> AuthResult? {
    guard let refreshToken = refreshToken else {
        throw AuthError.tokenExpired
    }
    
    // 새 Access Token 발급
    let response: APIResponse<LoginResponse> = try await networkClient.request(
        endpoint: "/auth/refresh",
        method: .POST,
        headers: ["Authorization": "Bearer \(refreshToken)"]
    )
}
```

**Access Token(짧은 수명) + Refresh Token(긴 수명)** 조합으로 보안과 UX를 균형맞춤.

### 💡 적용 사례
- **모바일 앱**: 오프라인 동작이 필요한 경우
- **마이크로서비스**: 서비스 간 통신이 많은 환경
- **SPA**: Single Page Application
- **API 서비스**: RESTful API 제공

---

## 🌐 OAuth2 인증 (3분)

### 특징 및 작동 원리

**OAuth2**는 **제3자 인증 위임** 방식입니다.

```swift
class OAuth2AuthService: AuthenticationService {
    func handleOAuth2Callback(code: String) async throws -> AuthResult {
        // 1. Authorization Code → Access Token 교환
        let tokenResponse = try await exchangeCodeForToken(code)
        
        // 2. Access Token으로 사용자 정보 조회
        let userInfo = try await fetchUserInfo(token: tokenResponse.accessToken)
        
        return AuthResult(user: userInfo, authType: .oauth2)
    }
}
```

### 🎯 장점
- **사용자 편의성**: 별도 회원가입 불필요
- **보안 향상**: 비밀번호를 직접 관리하지 않음
- **신뢰성**: Google, Apple 등 검증된 제공자
- **개발 효율성**: 인증 로직 외부 위임

### 🔒 단점
- **외부 의존성**: 제공자 서비스 장애 시 영향
- **데이터 제한**: 제공자가 허용하는 정보만 접근
- **복잡한 플로우**: Authorization Code, State 관리
- **프라이버시**: 사용자 데이터 추적 가능성

### 🔐 핵심 구현: Apple Sign-In

```swift
// Apple Sign-In은 iOS 13+에서 필수 요구사항
import AuthenticationServices

func signInWithApple() {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]
    
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.performRequests()
}
```

**Apple Sign-In**은 iOS에서 다른 소셜 로그인 제공 시 의무 구현 사항입니다.

### 💡 적용 사례
- **소셜 앱**: 빠른 온보딩이 중요한 경우
- **B2C 서비스**: 사용자 진입장벽을 낮춰야 할 때
- **iOS 앱**: Apple Sign-In 의무 구현
- **글로벌 서비스**: 다양한 지역 사용자 대응

---

## ⚖️ 방식별 비교 분석 (2분)

### 성능 비교

| 방식 | 서버 부하 | 확장성 | 네트워크 | 클라이언트 부하 |
|------|-----------|--------|----------|----------------|
| 세션 | 높음 | 제한적 | 낮음 | 낮음 |
| JWT | 낮음 | 높음 | 보통 | 보통 |
| OAuth2 | 중간 | 높음 | 높음 | 높음 |

### 보안 비교

| 방식 | 데이터 보호 | 즉시 무효화 | 취약점 | 관리 복잡도 |
|------|-------------|-------------|--------|-------------|
| 세션 | 높음 | 가능 | CSRF | 낮음 |
| JWT | 중간 | 어려움 | XSS | 중간 |
| OAuth2 | 높음 | 가능 | 복잡한 플로우 | 높음 |

### 개발 복잡도

**세션** < **JWT** < **OAuth2** 순으로 복잡도가 증가합니다.

---

## 🛠️ 기술적 구현 하이라이트 (3분)

### 1. 의존성 주입 (Dependency Injection) 아키텍처

현대 iOS 개발에서 **테스트 가능하고 유연한 코드**를 위해 필수적인 패턴입니다.

```swift
// 프로토콜 기반 추상화
protocol AuthenticationService {
    func login(credentials: AuthCredentials) async throws -> AuthResult
}

protocol TokenStorage {
    func store(token: String, for key: String) throws
    func retrieve(for key: String) throws -> String?
}
```

**왜 DI를 사용할까요?**

#### 🎯 핵심 이점
- **테스트 용이성**: Mock 객체로 쉬운 단위 테스트
- **느슨한 결합**: 구현체 변경 시 다른 코드 영향 최소화
- **런타임 교체**: 인증 방식을 동적으로 변경 가능

#### 🏗️ 팩토리 패턴과 결합

```swift
protocol AuthServiceFactory {
    func createService(for authType: AuthType) -> AuthenticationService
}

class AuthContainer {
    private let authServiceFactory: AuthServiceFactory
    
    func switchAuthType(_ authType: AuthType) {
        // 런타임에 인증 방식 교체 - DI의 핵심 장점!
        self.currentAuthService = authServiceFactory.createService(for: authType)
    }
}
```

#### 🔧 Builder 패턴으로 의존성 관리

```swift
// 기존: 하드코딩된 의존성
init() {
    let tokenStorage = KeychainTokenStorage()  // 강한 결합
    let networkClient = MockNetworkClient()    // 테스트 어려움
}

// 개선: DI를 통한 느슨한 결합
static func build() -> AuthContainer {
    let tokenStorage = KeychainTokenStorage()
    let networkClient = MockNetworkClient()
    let factory = DefaultAuthServiceFactory(
        tokenStorage: tokenStorage,
        networkClient: networkClient
    )
    
    return AuthContainer(authServiceFactory: factory)  // 주입
}
```

### 2. KeychainTokenStorage - iOS 보안의 핵심

iOS에서 **민감한 데이터 저장**을 위한 최고의 솔루션입니다.

#### 🔐 Keychain vs UserDefaults

| 저장소 | 암호화 | 앱 삭제 시 | 백업 | 적합한 데이터 |
|--------|--------|------------|------|---------------|
| **UserDefaults** | ❌ 평문 | 함께 삭제 | iCloud 포함 | 설정, 상태 |
| **Keychain** | ✅ 하드웨어 암호화 | 유지 가능 | 선택적 | 토큰, 비밀번호 |

#### 🛡️ 핵심 구현

```swift
class KeychainTokenStorage: TokenStorage {
    func store(token: String, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        // 기존 데이터 삭제 후 새로 저장
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw TokenStorageError.storeFailed
        }
    }
    
    func retrieve(for key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
}
```

#### 🔒 보안 수준 설정

```swift
// 다양한 접근성 옵션
kSecAttrAccessibleWhenUnlockedThisDeviceOnly    // 가장 안전 (백업 안됨)
kSecAttrAccessibleWhenUnlocked                  // 안전 (백업 됨)
kSecAttrAccessibleAfterFirstUnlock              // 백그라운드 접근 가능
```

#### 💡 실제 사용 사례

```swift
// JWT Access Token 저장
try tokenStorage.store(token: "eyJhbGciOiJIUzI1NiIs...", for: "access_token")

// Refresh Token 저장 (더 긴 수명)
try tokenStorage.store(token: "refresh_abc123...", for: "refresh_token")

// 앱 재시작 시 토큰 복원
if let savedToken = try? tokenStorage.retrieve(for: "access_token") {
    // 자동 로그인 처리
}
```

### 3. SwiftUI @Observable 최적화

```swift
@Observable
class AuthContainer {
    @ObservationTracked
    var isAuthenticated: Bool {
        currentAuthService.isAuthenticated
    }
}
```

**핵심 문제 해결**: `@Observable`의 프로퍼티 변경 감지를 위해 computed property와 `@ObservationTracked` 활용

### 4. 실제 프로덕션 고려사항

#### 🔐 보안 강화
- **Certificate Pinning**: 네트워크 보안
- **Jailbreak Detection**: 탈옥 기기 대응
- **App Transport Security**: HTTPS 강제

#### 📱 사용자 경험
- **생체인증 통합**: Face ID/Touch ID
- **자동 로그인**: 토큰 자동 갱신
- **오프라인 지원**: 로컬 검증

#### 🧪 테스트 전략
```swift
// DI 덕분에 쉬운 테스트
class MockTokenStorage: TokenStorage {
    private var storage: [String: String] = [:]
    
    func store(token: String, for key: String) throws {
        storage[key] = token
    }
    
    func retrieve(for key: String) throws -> String? {
        return storage[key]
    }
}

// 테스트에서 Mock 사용
let mockStorage = MockTokenStorage()
let authService = JWTAuthService(tokenStorage: mockStorage, networkClient: mockNetwork)
```

---

## 📊 실제 적용 가이드라인 (2분)

### 프로젝트 규모별 선택 가이드

#### 🏢 Enterprise (대규모)
- **JWT + OAuth2 조합**
- 확장성과 보안 모두 중요
- 마이크로서비스 아키텍처

#### 🏪 Startup (중소규모)
- **JWT 우선**
- 빠른 개발과 확장성
- 인프라 비용 절약

#### 🏠 Prototype (프로토타입)
- **세션 기반**
- 빠른 구현
- 기능 검증 우선

### 보안 요구사항별 선택

- **금융/의료**: 세션 + 추가 인증
- **일반 B2C**: JWT + OAuth2
- **내부 도구**: 세션 또는 JWT

### 사용자 경험 우선순위

- **편의성 우선**: OAuth2 (소셜 로그인)
- **속도 우선**: JWT (캐싱 가능)
- **제어 우선**: 세션 (즉시 차단)

---

## 🔮 미래 발전 방향 (1분)

### 1. 생체 인증 통합
```swift
import LocalAuthentication

func authenticateWithBiometrics() {
    let context = LAContext()
    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                          localizedReason: "로그인을 위한 생체 인증")
}
```

### 2. WebAuthn/FIDO2
- 패스워드 없는 인증
- 하드웨어 보안 키 지원

### 3. Zero Trust 아키텍처
- 모든 요청을 검증
- 컨텍스트 기반 인증

---

## 🎯 결론 및 질의응답 (1분)

### 핵심 메시지

1. **상황에 맞는 선택**: 절대적으로 좋은 인증 방식은 없습니다
2. **확장 가능한 설계**: 프로토콜 기반 아키텍처로 유연성 확보
3. **보안과 UX의 균형**: 사용자 편의성과 보안 요구사항의 트레이드오프

### 프로젝트 성과

- ✅ **3가지 인증 방식** 통합 구현
- ✅ **런타임 교체** 가능한 유연한 아키텍처  
- ✅ **SwiftUI @Observable** 최적화
- ✅ **의존성 주입** 패턴 적용

**"인증은 선택이 아닌 필수, 하지만 현명한 선택이 성공의 열쇠입니다."**

---

### 질의응답

궁금한 점이나 구체적인 구현에 대한 질문이 있으시면 언제든 말씀해 주세요!

---

**🎬 발표 시간: 약 23분 (각 섹션별 시간 배분 포함)**

## 📎 부록

### 추가 자료
- [프로젝트 GitHub Repository](#)
- [SwiftUI @Observable 공식 문서](https://developer.apple.com/documentation/observation)
- [JWT 공식 사이트](https://jwt.io/)
- [OAuth2 RFC 문서](https://tools.ietf.org/html/rfc6749)

### 연관 기술
- **Keychain Services**: 안전한 토큰 저장
- **Combine Framework**: 반응형 프로그래밍
- **AuthenticationServices**: Apple Sign-In
- **CryptoKit**: 암호화 및 해싱

### 프로젝트 구조
```
auth-system/
├── 📱 Authentication/
│   ├── Models/          # 사용자, 토큰, 세션 데이터 모델
│   ├── Services/        # 인증 서비스 (토큰, 세션, Apple)
│   ├── ViewModels/      # MVVM 패턴 ViewModel
│   ├── Views/           # 로그인/회원가입 UI
│   ├── Protocols/       # 인증 서비스 프로토콜
│   ├── Storage/         # Keychain 토큰 저장소
│   └── DI/              # 의존성 주입 컨테이너
├── 🌐 Network/          # API 클라이언트, 네트워크 관리
└── 🛠️ Utils/            # 확장, 유틸리티, 상수
```