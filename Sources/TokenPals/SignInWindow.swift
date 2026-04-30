// Sign-in window: 2-step Email OTP flow.
// Step 1: enter email, request OTP. Step 2: enter 6-digit code.

import Cocoa

class SignInWindow: NSWindow {
    private let auth: AuthManager
    var onSuccess: (() -> Void)?

    private enum Step {
        case email
        case code(email: String)
    }
    private var step: Step = .email

    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var emailField: NSTextField!
    private var codeField: NSTextField!
    private var primaryButton: NSButton!
    private var backButton: NSButton!
    private var statusLabel: NSTextField!
    private var progress: NSProgressIndicator!

    init(auth: AuthManager) {
        self.auth = auth
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = L10n.isKorean ? "TokenPals 로그인" : "TokenPals Sign In"
        contentView = makeContent()
        center()
        isReleasedWhenClosed = false
        renderForCurrentStep()
    }

    private func makeContent() -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 240))

        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .boldSystemFont(ofSize: 15)
        titleLabel.frame = NSRect(x: 20, y: 196, width: 340, height: 22)
        v.addSubview(titleLabel)

        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: 168, width: 340, height: 22)
        subtitleLabel.maximumNumberOfLines = 2
        v.addSubview(subtitleLabel)

        emailField = NSTextField(frame: NSRect(x: 20, y: 120, width: 340, height: 24))
        emailField.placeholderString = "your@email.com"
        emailField.target = self
        emailField.action = #selector(primaryPressed)
        v.addSubview(emailField)

        codeField = NSTextField(frame: NSRect(x: 20, y: 120, width: 340, height: 24))
        codeField.placeholderString = L10n.isKorean ? "이메일로 받은 인증 코드" : "Code from your email"
        codeField.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        codeField.target = self
        codeField.action = #selector(primaryPressed)
        codeField.isHidden = true
        v.addSubview(codeField)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.frame = NSRect(x: 20, y: 78, width: 340, height: 32)
        statusLabel.maximumNumberOfLines = 2
        v.addSubview(statusLabel)

        progress = NSProgressIndicator(frame: NSRect(x: 20, y: 24, width: 16, height: 16))
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        v.addSubview(progress)

        backButton = NSButton(title: L10n.isKorean ? "뒤로" : "Back", target: self, action: #selector(backPressed))
        backButton.bezelStyle = .rounded
        backButton.frame = NSRect(x: 174, y: 18, width: 90, height: 28)
        backButton.isHidden = true
        v.addSubview(backButton)

        primaryButton = NSButton(title: "", target: self, action: #selector(primaryPressed))
        primaryButton.bezelStyle = .rounded
        primaryButton.keyEquivalent = "\r"
        primaryButton.frame = NSRect(x: 270, y: 18, width: 90, height: 28)
        v.addSubview(primaryButton)

        return v
    }

    // MARK: - Rendering

    private func renderForCurrentStep() {
        switch step {
        case .email:
            titleLabel.stringValue = L10n.isKorean ? "이메일로 로그인" : "Sign in with email"
            subtitleLabel.stringValue = L10n.isKorean
                ? "이메일을 입력하시면 인증 코드를 보내드려요."
                : "Enter your email to receive a 6-digit code."
            primaryButton.title = L10n.isKorean ? "코드 보내기" : "Send code"
            backButton.isHidden = true
            emailField.isHidden = false
            codeField.isHidden = true
            statusLabel.stringValue = ""
            makeFirstResponder(emailField)

        case .code(let email):
            titleLabel.stringValue = L10n.isKorean ? "코드 입력" : "Enter code"
            subtitleLabel.stringValue = L10n.isKorean
                ? "\(email)로 보낸 인증 코드를 입력해주세요."
                : "Enter the code sent to \(email)."
            primaryButton.title = L10n.isKorean ? "확인" : "Verify"
            backButton.isHidden = false
            emailField.isHidden = true
            codeField.isHidden = false
            codeField.stringValue = ""
            statusLabel.stringValue = ""
            makeFirstResponder(codeField)
        }
    }

    private func setBusy(_ busy: Bool) {
        if busy {
            progress.startAnimation(nil)
        } else {
            progress.stopAnimation(nil)
        }
        primaryButton.isEnabled = !busy
        backButton.isEnabled = !busy
        emailField.isEnabled = !busy
        codeField.isEnabled = !busy
    }

    private func showError(_ message: String) {
        statusLabel.textColor = NSColor.systemRed
        statusLabel.stringValue = message
    }

    private func showInfo(_ message: String) {
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.stringValue = message
    }

    // MARK: - Actions

    @objc private func primaryPressed() {
        switch step {
        case .email:
            let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidEmail(email) else {
                showError(L10n.isKorean ? "유효한 이메일을 입력해주세요." : "Please enter a valid email.")
                return
            }
            sendCode(to: email)

        case .code(let email):
            let code = codeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            // Supabase OTP 길이는 6~10자리 (설정에 따라 다름). 숫자만 + 길이 범위 체크.
            guard code.count >= 6, code.count <= 10, code.allSatisfy({ $0.isNumber }) else {
                showError(L10n.isKorean ? "이메일로 받은 코드를 정확히 입력해주세요." : "Please enter the code from your email.")
                return
            }
            verifyCode(email: email, code: code)
        }
    }

    @objc private func backPressed() {
        step = .email
        renderForCurrentStep()
    }

    private func sendCode(to email: String) {
        setBusy(true)
        showInfo(L10n.isKorean ? "코드 전송 중..." : "Sending code...")
        Task {
            do {
                try await auth.sendOTP(email: email)
                await MainActor.run {
                    self.setBusy(false)
                    self.step = .code(email: email)
                    self.renderForCurrentStep()
                    self.showInfo(L10n.isKorean ? "메일함을 확인해주세요." : "Check your inbox.")
                }
            } catch {
                await MainActor.run {
                    self.setBusy(false)
                    self.showError("\(L10n.isKorean ? "오류" : "Error"): \(error.localizedDescription)")
                }
            }
        }
    }

    private func verifyCode(email: String, code: String) {
        setBusy(true)
        showInfo(L10n.isKorean ? "확인 중..." : "Verifying...")
        Task {
            do {
                _ = try await auth.verifyOTP(email: email, code: code)
                await MainActor.run {
                    self.setBusy(false)
                    self.onSuccess?()
                    self.close()
                }
            } catch {
                await MainActor.run {
                    self.setBusy(false)
                    self.showError("\(L10n.isKorean ? "오류" : "Error"): \(error.localizedDescription)")
                }
            }
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        // 간단 검증 — `@` + `.` 있는지
        guard s.contains("@"), let at = s.firstIndex(of: "@") else { return false }
        let domain = s[s.index(after: at)...]
        return domain.contains(".") && domain.count >= 3
    }
}
