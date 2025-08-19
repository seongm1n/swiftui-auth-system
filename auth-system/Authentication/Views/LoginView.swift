import SwiftUI

// MARK: - 로그인 화면
struct LoginView: View {
    @Environment(\.authContainer) private var authContainer
    @State private var authViewModel: AuthViewModel?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 헤더
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("로그인")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("현재: \(authViewModel?.currentAuthType.displayName ?? "로딩중")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // 로그인 폼
                VStack(spacing: 16) {
                    // 이메일 입력
                    VStack(alignment: .leading, spacing: 4) {
                        Text("이메일")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("이메일을 입력하세요", text: Binding(
                            get: { authViewModel?.email ?? "" },
                            set: { authViewModel?.email = $0 }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(authViewModel?.isLoading ?? false)
                    }
                    
                    // 비밀번호 입력
                    VStack(alignment: .leading, spacing: 4) {
                        Text("비밀번호")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("비밀번호를 입력하세요", text: Binding(
                            get: { authViewModel?.password ?? "" },
                            set: { authViewModel?.password = $0 }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .disabled(authViewModel?.isLoading ?? false)
                    }
                    
                    // 로그인 버튼
                    Button {
                        Task {
                            await authViewModel?.login()
                        }
                    } label: {
                        HStack {
                            if authViewModel?.isLoading == true {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(authViewModel?.isLoading == true ? "로그인 중..." : "로그인")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(authViewModel?.canLogin == true ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authViewModel?.canLogin != true)
                }
                .padding(.horizontal, 32)
                
                // 인증 방식 선택
                VStack(spacing: 12) {
                    Text("인증 방식 변경")
                        .font(.headline)
                        .padding(.top, 20)
                    
                    HStack(spacing: 12) {
                        ForEach(AuthType.allCases, id: \.self) { authType in
                            Button {
                                authViewModel?.switchAuthType(authType)
                            } label: {
                                Text(authType.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        authType == authViewModel?.currentAuthType ? 
                                        Color.blue : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        authType == authViewModel?.currentAuthType ? 
                                        .white : .primary
                                    )
                                    .cornerRadius(8)
                            }
                            .disabled(authViewModel?.isLoading == true)
                        }
                    }
                }
                
                Spacer()
                
                // 테스트 계정 정보
                VStack(spacing: 4) {
                    Text("테스트 계정")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("test@example.com / password123")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("admin@example.com / admin123")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
            .alert("오류", isPresented: Binding(
                get: { authViewModel?.showError ?? false },
                set: { authViewModel?.showError = $0 }
            )) {
                Button("확인") { }
            } message: {
                Text(authViewModel?.errorMessage ?? "")
            }
            .onAppear {
                if authViewModel == nil {
                    authViewModel = AuthViewModel(authContainer: authContainer)
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(\.authContainer, AuthContainer.shared)
}