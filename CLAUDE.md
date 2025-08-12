# SwiftUI 인증 시스템 프로젝트

## 프로젝트 개요
다양한 로그인 방식(세션, 토큰, Apple Sign-In)을 지원하는 종합적인 SwiftUI 인증 시스템

## 아키텍처 설계

### 폴더 구조
```
auth-system/
├── 📱 Authentication/
│   ├── Models/          # 사용자, 토큰, 세션 데이터 모델
│   ├── Services/        # 인증 서비스 (토큰, 세션, Apple)
│   ├── ViewModels/      # MVVM 패턴 ViewModel
│   └── Views/           # 로그인/회원가입 UI
├── 🌐 Network/          # API 클라이언트, 네트워크 관리
├── 🔐 Security/         # 생체인증, 암호화, 보안 정책
├── 💾 Storage/          # CoreData, UserDefaults, 지속성
├── 🎨 UI/
│   ├── Components/      # 재사용 가능한 UI 컴포넌트
│   └── Styles/          # 테마, 스타일 정의
└── 🛠️ Utils/            # 확장, 유틸리티, 상수
    └── Extensions/      # Swift 확장 메서드
```

## 인증 방식

### 1. 세션 기반 인증
- 서버 세션 상태 관리
- 쿠키 기반 인증
- CSRF 보호 구현

### 2. JWT 토큰 인증
- Stateless 인증 방식
- Access/Refresh Token 패턴
- Keychain 안전 저장

### 3. Apple Sign-In
- iOS 네이티브 인증
- Privacy 친화적
- AuthenticationServices 프레임워크 활용

## 인증 플로우

### 통합 인증 플로우
```
앱 시작 → 토큰/세션 확인 → 자동 로그인 or 로그인 화면
로그인 화면 → [이메일/패스워드, Apple Sign-In, 생체인증]
인증 성공 → 토큰/세션 저장 → 메인 화면
```

### 핵심 데이터 모델
- **User**: 사용자 정보 (id, email, provider, 등)
- **AuthToken**: JWT 토큰 정보
- **Session**: 세션 상태 관리
- **AuthError**: 인증 관련 에러 처리

### 핵심 서비스
- **AuthenticationManager**: 통합 인증 관리자
- **TokenService**: JWT 토큰 관리
- **SessionService**: 세션 관리  
- **AppleAuthService**: Apple Sign-In 처리
- **KeychainService**: 안전한 데이터 저장

## 구현 우선순위

### Phase 1: 기본 구조
- 데이터 모델 생성 (User, AuthToken, AuthError)
- KeychainService 구현
- 기본 UI 컴포넌트

### Phase 2: 토큰 인증
- TokenService 구현
- APIClient 구현
- AuthenticationManager 통합

### Phase 3: Apple Sign-In
- AppleAuthService 구현
- Apple Sign-In 버튼 통합
- Identity Token 처리

### Phase 4: 세션 인증
- SessionService 구현
- 쿠키 관리 로직
- 세션 만료 처리

### Phase 5: 고급 기능
- 생체 인증 (Face ID/Touch ID)
- 자동 로그인 기능
- 보안 정책 강화

## 보안 고려사항
- **Keychain**: 민감한 토큰 저장
- **SSL Pinning**: 네트워크 보안
- **Biometric**: 추가 인증 계층
- **Token Rotation**: 정기적 토큰 갱신
- **Error Handling**: 보안 정보 노출 방지

## 개발 가이드
- MVVM 패턴 준수
- SwiftUI + Combine 활용
- iOS 15+ 타겟
- 다국어 지원 고려
- 테스트 주도 개발 (TDD)

## 다음 단계
1. Phase 1 구현 시작
2. 데이터 모델 먼저 구현
3. KeychainService 개발
4. 기본 UI 작업