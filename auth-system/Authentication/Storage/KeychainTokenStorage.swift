import Foundation
import Security

// MARK: - Keychain 기반 토큰 저장소
class KeychainTokenStorage: TokenStorage {
    private let service = "auth-system.tokens"
    
    func store(token: String, for key: String) throws {
        let data = token.data(using: .utf8)!
        
        // 기존 항목 삭제
        try? delete(for: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw TokenStorageError.storeFailed(status)
        }
    }
    
    func retrieve(for key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw TokenStorageError.retrieveFailed(status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw TokenStorageError.invalidData
        }
        
        return token
    }
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStorageError.deleteFailed(status)
        }
    }
    
    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStorageError.clearFailed(status)
        }
    }
}

// MARK: - 토큰 저장소 에러
enum TokenStorageError: LocalizedError {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case clearFailed(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "토큰 저장 실패: \(status)"
        case .retrieveFailed(let status):
            return "토큰 조회 실패: \(status)"
        case .deleteFailed(let status):
            return "토큰 삭제 실패: \(status)"
        case .clearFailed(let status):
            return "토큰 전체 삭제 실패: \(status)"
        case .invalidData:
            return "유효하지 않은 토큰 데이터"
        }
    }
}