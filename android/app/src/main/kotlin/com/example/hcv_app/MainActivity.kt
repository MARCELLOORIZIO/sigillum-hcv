package com.example.hcv_app

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.interfaces.RSAPublicKey
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val INTENT_CHANNEL = "hcv.intent"
    private val KEYSTORE_CHANNEL = "hcv.keystore"
    private val KEY_ALIAS = "hcv_rsa_signing_key_v1"
    private val SECRET_KEY_ALIAS = "hcv_account_secret_key_v1"
    private val SECRET_PREFS = "hcv_secure_account_store"

    private var sharedPath: String? = null
    private var intentChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        intentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INTENT_CHANNEL
        )

        val keystoreChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KEYSTORE_CHANNEL
        )

        handleIntent(intent)

        intentChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedPath" -> {
                    result.success(sharedPath)
                    sharedPath = null
                }
                else -> result.notImplemented()
            }
        }

        keystoreChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "sign" -> {
                        val data = call.argument<String>("data")
                        if (data.isNullOrEmpty()) {
                            result.error("INVALID_DATA", "Data is empty", null)
                            return@setMethodCallHandler
                        }

                        result.success(signWithKeystore(data))
                    }

                    "getPublicKey" -> {
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

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("KEYSTORE_ERROR", e.message, null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        handleIntent(intent)

        intentChannel?.invokeMethod("onSharedPath", sharedPath)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        when (intent.action) {
            Intent.ACTION_VIEW -> {
                intent.data?.let { uri ->
                    sharedPath = copyUriToCache(uri)
                }
            }

            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                uri?.let {
                    sharedPath = copyUriToCache(it)
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val input = contentResolver.openInputStream(uri) ?: return null

            val extension = resolveExtension(uri)
            val fileName = "shared_${System.currentTimeMillis()}$extension"
            val outFile = File(cacheDir, fileName)

            input.use { inputStream ->
                outFile.outputStream().use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }

            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun resolveExtension(uri: Uri): String {
        val displayName = queryDisplayName(uri)
        val displayExtension = displayName
            ?.substringAfterLast('.', "")
            ?.lowercase()

        if (!displayExtension.isNullOrBlank() && displayExtension.length <= 8) {
            return ".$displayExtension"
        }

        val mime = contentResolver.getType(uri)
        val mimeExtension = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(mime)
            ?.lowercase()

        if (!mimeExtension.isNullOrBlank()) {
            return ".$mimeExtension"
        }

        return ".bin"
    }

    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null

        return try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )

            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else {
                null
            }
        } catch (e: Exception) {
            null
        } finally {
            cursor?.close()
        }
    }

    private fun getOrCreateSecretKey(): SecretKey {
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

    private fun getOrCreateKey() {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        if (keyStore.containsAlias(KEY_ALIAS)) {
            return
        }

        val keyPairGenerator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_RSA,
            "AndroidKeyStore"
        )

        val parameterSpec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
            .setKeySize(2048)
            .build()

        keyPairGenerator.initialize(parameterSpec)
        keyPairGenerator.generateKeyPair()
    }

    private fun signWithKeystore(data: String): String {
        getOrCreateKey()

        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        val privateKey = keyStore.getKey(KEY_ALIAS, null)

        val signature = Signature.getInstance("SHA256withRSA")
        signature.initSign(privateKey as java.security.PrivateKey)
        signature.update(data.toByteArray(Charsets.UTF_8))

        return Base64.getEncoder().encodeToString(signature.sign())
    }

    private fun getPublicKeyMap(): Map<String, String> {
        getOrCreateKey()

        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        val certificate = keyStore.getCertificate(KEY_ALIAS)
        val publicKey = certificate.publicKey as RSAPublicKey

        return mapOf(
            "modulus" to bigIntegerToBase64(publicKey.modulus),
            "exponent" to bigIntegerToBase64(publicKey.publicExponent)
        )
    }

    private fun bigIntegerToBase64(value: BigInteger): String {
        var bytes = value.toByteArray()

        if (bytes.isNotEmpty() && bytes[0].toInt() == 0) {
            bytes = bytes.copyOfRange(1, bytes.size)
        }

        return Base64.getEncoder().encodeToString(bytes)
    }
}
