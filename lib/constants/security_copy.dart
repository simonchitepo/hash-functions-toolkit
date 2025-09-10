/// ----------------------------
/// SECURITY COPY (Disclaimer + Best Practices)
/// ----------------------------

// Intentionally UI-free. Keep this file limited to copy strings so it can be
// imported by any layer without pulling Flutter widget dependencies.

class SecurityCopy {
  static const String shortFooter =
      "Security note: records are encrypted with your PIN. If you forget the PIN, the encrypted data cannot be recovered.";

  static const String title = "Security & Privacy Disclaimer";

  static const String disclaimer = """
This tool helps reduce accidental exposure of sensitive information by masking values in the user interface and storing records in encrypted form. It is not a substitute for enterprise-grade secrets management, compliance controls, or secure key management.

• Masking is not encryption. Masking hides characters on-screen but does not protect data if the underlying value is exposed elsewhere (e.g., browser memory, logs, screenshots, or exports).
• Client-side encryption depends on your PIN/passphrase. Records are encrypted locally and may be exported and shared in encrypted form. If your PIN/passphrase is weak or reused, an attacker who obtains an encrypted export could attempt offline guessing.
• No recovery if you forget your PIN/passphrase. For “zero-knowledge” protection, the application cannot recover encrypted data without the correct PIN/passphrase.
• Your environment matters. Use this tool only on trusted devices and networks. Malware, compromised browsers/extensions, or shared computers can defeat app-level protections.

By using this tool, you acknowledge these limitations and agree to follow the recommended security practices below.
""";

  static const String bestPracticesTitle = "Good Practices";

  static const String bestPractices = """
Masking best practices (reduces accidental exposure)
• Mask by default; reveal only when necessary.
• Minimize what you reveal (last 4 characters or less where possible).
• Avoid storing or copying decrypted values into notes, tickets, or chats.
• Never include sensitive values in analytics, logs, or error reports.

PIN/passphrase best practices (protects encrypted data)
• A 6-digit PIN is low entropy. For high-value secrets, use a longer passphrase (12+ characters) or a password manager.
• Never reuse credentials across services.
• Use trusted devices; keep your OS/browser updated; beware of malicious extensions.

Storage and sharing best practices (reduces breach impact)
• Treat exports as sensitive even if encrypted.
• Share ciphertext only; do not share decrypted values.
• If you must share the PIN/passphrase, do so via a separate secure channel.

Threat model guidance
Appropriate for: reducing screen exposure, storing personal reference data with basic protection, sharing encrypted blobs.
Not appropriate for: regulated production secrets without a dedicated secrets manager, or scenarios requiring password recovery, centralized rotation, or audit controls.
""";

  static const String storageNote = """
Storage scope note:
This app stores data persistently in your current browser profile (IndexedDB via Hive). It will not automatically sync across devices.
""";
}
