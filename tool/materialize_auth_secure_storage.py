from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    if source.count(old) != 1:
        raise RuntimeError(f'Unable to patch {label}: expected one anchor, found {source.count(old)}')
    return source.replace(old, new, 1)


swift_path = Path('ios/Runner/SceneDelegate.swift')
swift = swift_path.read_text()

swift_old_handler = '''        } else if call.method == "getPublicKey" {
          result(try self.getPublicKeyMap())
        } else {
          result(FlutterMethodNotImplemented)
        }'''
swift_new_handler = '''        } else if call.method == "getPublicKey" {
          result(try self.getPublicKeyMap())
        } else if call.method == "setSecret" {
          guard
            let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            let value = args["value"] as? String,
            !key.isEmpty
          else {
            result(FlutterError(code: "INVALID_SECRET", message: "Secret key is empty", details: nil))
            return
          }
          try self.setKeychainSecret(key: key, value: value)
          result(nil)
        } else if call.method == "getSecret" {
          guard
            let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            !key.isEmpty
          else {
            result(FlutterError(code: "INVALID_SECRET", message: "Secret key is empty", details: nil))
            return
          }
          result(try self.getKeychainSecret(key: key))
        } else if call.method == "deleteSecret" {
          guard
            let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            !key.isEmpty
          else {
            result(FlutterError(code: "INVALID_SECRET", message: "Secret key is empty", details: nil))
            return
          }
          try self.deleteKeychainSecret(key: key)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }'''
swift = replace_once(swift, swift_old_handler, swift_new_handler, 'iOS method channel')

swift_anchor = '''  private func getOrCreatePrivateKey() throws -> SecKey {'''
swift_helpers = '''  private let secretService = "com.sigillum.hcv.secure"

  private func secretQuery(key: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: secretService,
      kSecAttrAccount as String: key
    ]
  }

  private func setKeychainSecret(key: String, value: String) throws {
    var query = secretQuery(key: key)
    SecItemDelete(query as CFDictionary)
    query[kSecValueData as String] = Data(value.utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "Unable to save secure account session"]
      )
    }
  }

  private func getKeychainSecret(key: String) throws -> String? {
    var query = secretQuery(key: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess, let data = item as? Data else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "Unable to read secure account session"]
      )
    }
    return String(data: data, encoding: .utf8)
  }

  private func deleteKeychainSecret(key: String) throws {
    let status = SecItemDelete(secretQuery(key: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "Unable to delete secure account session"]
      )
    }
  }

  private func getOrCreatePrivateKey() throws -> SecKey {'''
swift = replace_once(swift, swift_anchor, swift_helpers, 'iOS Keychain helpers')
swift_path.write_text(swift)

android_path = Path('android/app/src/main/kotlin/com/example/hcv_app/MainActivity.kt')
android = android_path.read_text()

android = replace_once(
    android,
    'import java.util.Base64\n',
    '''import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
''',
    'Android crypto imports',
)

android = replace_once(
    android,
    '''    private val KEY_ALIAS = "hcv_rsa_signing_key_v1"
''',
    '''    private val KEY_ALIAS = "hcv_rsa_signing_key_v1"
    private val SECRET_KEY_ALIAS = "hcv_account_secret_key_v1"
    private val SECRET_PREFS = "hcv_secure_account_store"
''',
    'Android secure constants',
)

android_old_handler = '''                    "getPublicKey" -> {
                        result.success(getPublicKeyMap())
                    }

                    else -> result.notImplemented()'''
android_new_handler = '''                    "getPublicKey" -> {
                        result.success(getPublicKeyMap())
                    }

                    "setSecret" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        if (key.isNullOrEmpty() || value == null) {
                            result.error("INVALID_SECRET", "Secret key is empty", null)
                            return@setMethodCallHandler
                        }
                        setSecret(key, value)
                        result.success(null)
                    }

                    "getSecret" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrEmpty()) {
                            result.error("INVALID_SECRET", "Secret key is empty", null)
                            return@setMethodCallHandler
                        }
                        result.success(getSecret(key))
                    }

                    "deleteSecret" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrEmpty()) {
                            result.error("INVALID_SECRET", "Secret key is empty", null)
                            return@setMethodCallHandler
                        }
                        deleteSecret(key)
                        result.success(null)
                    }

                    else -> result.notImplemented()'''
android = replace_once(android, android_old_handler, android_new_handler, 'Android method channel')

android_anchor = '''    private fun getOrCreateKey() {'''
android_helpers = '''    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)
        val existing = keyStore.getKey(SECRET_KEY_ALIAS, null)
        if (existing is SecretKey) return existing

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )
        val spec = KeyGenParameterSpec.Builder(
            SECRET_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    private fun setSecret(key: String, value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val encoded = Base64.getEncoder().encodeToString(cipher.iv) + "." +
            Base64.getEncoder().encodeToString(encrypted)
        getSharedPreferences(SECRET_PREFS, MODE_PRIVATE)
            .edit()
            .putString(key, encoded)
            .apply()
    }

    private fun getSecret(key: String): String? {
        val encoded = getSharedPreferences(SECRET_PREFS, MODE_PRIVATE)
            .getString(key, null) ?: return null
        val parts = encoded.split('.', limit = 2)
        if (parts.size != 2) return null
        val iv = Base64.getDecoder().decode(parts[0])
        val encrypted = Base64.getDecoder().decode(parts[1])
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateSecretKey(),
            GCMParameterSpec(128, iv)
        )
        return String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }

    private fun deleteSecret(key: String) {
        getSharedPreferences(SECRET_PREFS, MODE_PRIVATE)
            .edit()
            .remove(key)
            .apply()
    }

    private fun getOrCreateKey() {'''
android = replace_once(android, android_anchor, android_helpers, 'Android encrypted storage helpers')
android_path.write_text(android)

print('Native Keychain and Android Keystore account storage materialized')
