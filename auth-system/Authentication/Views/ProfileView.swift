import SwiftUI

// MARK: - 프로필 화면 (로그인 후)
struct ProfileView: View {
    @State private var authViewModel = AuthViewModel()
    @Environment(\.authContainer) private var authContainer
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 사용자 정보 헤더
                VStack(spacing: 12) {
                    // 아바타
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    // 사용자 정보
                    if let user = authViewModel.currentUser {
                        VStack(spacing: 4) {
                            Text(user.name ?? "사용자")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text(user.provider.rawValue.capitalized + " 계정")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 40)
                
                // 인증 상태 정보
                VStack(spacing: 16) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("인증 상태")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            InfoRow(title: "인증 방식", value: authViewModel.currentAuthType.displayName)
                            InfoRow(title: "로그인 상태", value: authViewModel.isAuthenticated ? "인증됨" : "미인증")
                            
                            if let user = authViewModel.currentUser {
                                InfoRow(title: "사용자 ID", value: user.id)
                                InfoRow(title: "제공자", value: user.provider.rawValue.capitalized)
                            }
                        }
                        .padding()
                    }
                }
                .padding(.horizontal, 20)
                
                // 액션 버튼들
                VStack(spacing: 12) {
                    // 인증 갱신 버튼
                    Button {
                        Task {
                            await authViewModel.refreshAuth()
                        }
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "arrow.clockwise")
                            Text("인증 갱신")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authViewModel.isLoading)
                    
                    // 로그아웃 버튼
                    Button {
                        Task {
                            await authViewModel.logout()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("로그아웃")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 인증 방식 변경
                VStack(spacing: 12) {
                    Text("다른 인증 방식으로 변경")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(AuthType.allCases, id: \.self) { authType in
                            if authType != authViewModel.currentAuthType {
                                Button {
                                    authViewModel.switchAuthType(authType)
                                } label: {
                                    Text(authType.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                                .disabled(authViewModel.isLoading)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.inline)
            .alert("오류", isPresented: $authViewModel.showError) {
                Button("확인") { }
            } message: {
                Text(authViewModel.errorMessage)
            }
        }
    }
}

// MARK: - 정보 행 컴포넌트
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ProfileView()
        .environment(\.authContainer, AuthContainer.shared)
}