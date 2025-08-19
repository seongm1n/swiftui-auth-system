import Foundation
import SwiftUI

// MARK: - 인증 뷰모델
@Observable
class AuthViewModel {
    
    // MARK: - Properties
    private let authContainer: AuthContainer
    
    // UI 상태
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false
    
    // 인증 상태 (AuthContainer에서 위임)
    var isAuthenticated: Bool {
        authContainer.isAuthenticated
    }
    
    var currentUser: User? {
        authContainer.currentUser
    }
    
    var currentAuthType: AuthType {
        authContainer.currentAuthType
    }
    
    // MARK: - Initialization
    init(authContainer: AuthContainer = AuthContainer.shared) {
        self.authContainer = authContainer
        
        // 테스트용 기본 값
        #if DEBUG
        self.email = "test@example.com"
        self.password = "password123"
        #endif
    }
    
    // MARK: - Actions
    
    @MainActor
    func login() async {
        guard !email.isEmpty && !password.isEmpty else {
            showError(message: "이메일과 비밀번호를 입력해주세요.")
            return
        }
        
        isLoading = true
        clearError()
        
        do {
            let credentials = AuthCredentials(email: email, password: password)
            let result = try await authContainer.currentAuthService.login(credentials: credentials)
            
            print("로그인 성공: \(result.user.email) (\(result.authType.displayName))")
            
            // 로그인 성공시 필드 초기화
            clearFields()
            
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    @MainActor
    func logout() async {
        isLoading = true
        clearError()
        
        do {
            try await authContainer.currentAuthService.logout()
            print("로그아웃 성공")
            clearFields()
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    @MainActor
    func switchAuthType(_ authType: AuthType) {
        authContainer.switchAuthType(authType)
        clearError()
        print("인증 방식 변경: \(authType.displayName)")
    }
    
    @MainActor
    func refreshAuth() async {
        isLoading = true
        clearError()
        
        do {
            let result = try await authContainer.currentAuthService.refreshAuth()
            if let result = result {
                print("인증 갱신 성공: \(result.user.email)")
            }
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Validation
    
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var isValidPassword: Bool {
        return password.count >= 6
    }
    
    var canLogin: Bool {
        return !email.isEmpty && !password.isEmpty && !isLoading
    }
    
    // MARK: - Private Methods
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func clearError() {
        errorMessage = ""
        showError = false
    }
    
    private func clearFields() {
        #if !DEBUG
        email = ""
        password = ""
        #endif
    }
}