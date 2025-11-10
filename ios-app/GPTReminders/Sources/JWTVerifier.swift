import Foundation
import CryptoKit

/// Verifies RS256 JWT signatures from the server
struct JWTVerifier {
    private let publicKey: SecKey

    init(pemString: String) throws {
        // Remove PEM header/footer and whitespace
        let key = pemString
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let keyData = Data(base64Encoded: key) else {
            throw JWTError.invalidPublicKey
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(
            keyData as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            throw JWTError.invalidPublicKey
        }

        self.publicKey = secKey
    }

    func verify(token: String) throws -> [String: Any] {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw JWTError.invalidFormat
        }

        let headerAndPayload = parts[0...1].joined(separator: ".")
        guard let signatureData = base64URLDecode(String(parts[2])),
              let messageData = headerAndPayload.data(using: .utf8) else {
            throw JWTError.invalidFormat
        }

        // Verify signature
        var error: Unmanaged<CFError>?
        let verified = SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            messageData as CFData,
            signatureData as CFData,
            &error
        )

        guard verified else {
            throw JWTError.signatureInvalid
        }

        // Decode payload
        guard let payloadData = base64URLDecode(String(parts[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw JWTError.invalidPayload
        }

        // Verify expiration
        if let exp = payload["exp"] as? Int {
            let now = Int(Date().timeIntervalSince1970)
            if now > exp {
                throw JWTError.expired
            }
        }

        return payload
    }

    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}

// MARK: - Errors

enum JWTError: LocalizedError {
    case invalidPublicKey
    case invalidFormat
    case signatureInvalid
    case invalidPayload
    case expired

    var errorDescription: String? {
        switch self {
        case .invalidPublicKey:
            return "Invalid public key"
        case .invalidFormat:
            return "Invalid JWT format"
        case .signatureInvalid:
            return "JWT signature verification failed"
        case .invalidPayload:
            return "Invalid JWT payload"
        case .expired:
            return "JWT expired"
        }
    }
}
