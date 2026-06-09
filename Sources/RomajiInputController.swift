import Cocoa
import InputMethodKit

/// The heart of the IME. Buffers latin/romaji input as marked (underlined)
/// preedit text with a movable caret, then converts the whole paragraph to
/// Japanese via a local LLM when the user presses Enter.
@objc(RomajiInputController)
class RomajiInputController: IMKInputController {

    /// Accumulated romaji / mixed input shown as preedit.
    private var buffer = ""
    /// Caret position as a Character index into `buffer` (0...buffer.count).
    private var caret = 0
    /// True while a conversion request is in flight; swallow keys until done.
    private var converting = false

    private let notFound = NSRange(location: NSNotFound, length: 0)

    // Virtual key codes
    private let kReturn: UInt16 = 36
    private let kEnter: UInt16 = 76        // numpad enter
    private let kDelete: UInt16 = 51       // backspace
    private let kForwardDelete: UInt16 = 117
    private let kEscape: UInt16 = 53
    private let kLeft: UInt16 = 123
    private let kRight: UInt16 = 124
    private let kDown: UInt16 = 125
    private let kUp: UInt16 = 126
    private let kHome: UInt16 = 115
    private let kEnd: UInt16 = 119

    // MARK: - Event handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }
        guard let client = sender as? IMKTextInput else { return false }

        // While a conversion is running, ignore further keystrokes.
        if converting { return true }

        let code = event.keyCode
        let flags = event.modifierFlags
        let composing = !buffer.isEmpty

        switch code {
        case kReturn, kEnter:
            if !composing { return false } // pass through as a normal newline
            if flags.contains(.shift) {
                insert("\n")          // Shift+Enter: literal newline in the buffer
                updateMarked(client)
                return true
            }
            convert(client: client)
            return true

        case kDelete:                  // backspace: delete char before caret
            if !composing { return false }
            if caret > 0 {
                let idx = buffer.index(buffer.startIndex, offsetBy: caret - 1)
                buffer.remove(at: idx)
                caret -= 1
            }
            updateMarked(client)
            return true

        case kForwardDelete:           // delete char at caret
            if !composing { return false }
            if caret < buffer.count {
                let idx = buffer.index(buffer.startIndex, offsetBy: caret)
                buffer.remove(at: idx)
            }
            updateMarked(client)
            return true

        case kEscape:
            if !composing { return false }
            clear(client)
            return true

        // Arrow / navigation keys: move the caret inside the preedit while
        // composing; pass through to the app (normal cursor movement) otherwise.
        case kLeft:
            if !composing { return false }
            caret = max(0, caret - 1)
            updateMarked(client)
            return true

        case kRight:
            if !composing { return false }
            caret = min(buffer.count, caret + 1)
            updateMarked(client)
            return true

        case kUp, kHome:
            if !composing { return false }
            caret = 0
            updateMarked(client)
            return true

        case kDown, kEnd:
            if !composing { return false }
            caret = buffer.count
            updateMarked(client)
            return true

        default:
            break
        }

        // Command/Control combos: let the app handle them. Commit raw buffer first
        // so shortcuts don't act on a hidden composition.
        if flags.contains(.command) || flags.contains(.control) {
            if composing { commitRaw(client) }
            return false
        }

        // Printable characters: insert at the caret.
        if let chars = event.characters, isPrintable(chars) {
            insert(chars)
            updateMarked(client)
            return true
        }

        // Anything else (function keys, etc.) passes through to the app.
        return false
    }

    /// Accept only genuinely printable text. Rejects control chars, DEL, and the
    /// 0xF700–0xF8FF private-use range Cocoa uses for arrows / function keys —
    /// which previously leaked into the buffer as garbage.
    private func isPrintable(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        for scalar in s.unicodeScalars {
            let v = scalar.value
            if v < 0x20 || v == 0x7F { return false }
            if v >= 0xF700 && v <= 0xF8FF { return false }
        }
        return true
    }

    private func insert(_ s: String) {
        let idx = buffer.index(buffer.startIndex, offsetBy: caret)
        buffer.insert(contentsOf: s, at: idx)
        caret += s.count
    }

    // MARK: - Marked text / commit

    /// Render the buffer as preedit with the insertion point at `caret`.
    private func updateMarked(_ client: IMKTextInput) {
        let utf16Caret = (String(buffer.prefix(caret)) as NSString).length
        client.setMarkedText(
            buffer,
            selectionRange: NSRange(location: utf16Caret, length: 0),
            replacementRange: notFound
        )
    }

    private func showConverting(_ client: IMKTextInput) {
        let display = buffer + " ⟳"
        client.setMarkedText(
            display,
            selectionRange: NSRange(location: (display as NSString).length, length: 0),
            replacementRange: notFound
        )
    }

    private func clear(_ client: IMKTextInput) {
        buffer = ""
        caret = 0
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: notFound)
    }

    private func commitRaw(_ client: IMKTextInput) {
        let raw = buffer
        buffer = ""
        caret = 0
        client.insertText(raw, replacementRange: notFound)
    }

    // MARK: - Conversion

    private func convert(client: IMKTextInput) {
        let source = buffer
        converting = true
        showConverting(client)

        LLMClient.shared.convert(source) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.converting = false
                self.buffer = ""
                self.caret = 0
                switch result {
                case .success(let japanese):
                    client.insertText(japanese, replacementRange: self.notFound)
                case .failure(let error):
                    NSLog("RomajiAI: conversion failed: \(error.localizedDescription)")
                    // Fallback: commit the raw input so nothing is lost.
                    client.insertText(source, replacementRange: self.notFound)
                }
            }
        }
    }

    // MARK: - Lifecycle

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput, !buffer.isEmpty else { return }
        commitRaw(client)
    }

    override func deactivateServer(_ sender: Any!) {
        if let client = sender as? IMKTextInput, !buffer.isEmpty {
            commitRaw(client)
        }
        super.deactivateServer(sender)
    }

    // MARK: - Menu (shown when clicking the IME in the menu bar)

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "AIかな")
        let cfg = Config.load()

        let lm = NSMenuItem(title: "バックエンド: LM Studio", action: #selector(useLMStudio), keyEquivalent: "")
        lm.state = cfg.backend == .lmstudio ? .on : .off
        let ol = NSMenuItem(title: "バックエンド: Ollama", action: #selector(useOllama), keyEquivalent: "")
        ol.state = cfg.backend == .ollama ? .on : .off
        menu.addItem(lm)
        menu.addItem(ol)
        menu.addItem(.separator())

        menu.addItem(withTitle: "設定ファイルを編集…", action: #selector(openConfig), keyEquivalent: "")
        menu.addItem(withTitle: "LLM 接続テスト", action: #selector(testConnection), keyEquivalent: "")

        for item in menu.items where !item.isSeparatorItem { item.target = self }
        return menu
    }

    @objc private func useLMStudio() { Config.setBackend(.lmstudio) }
    @objc private func useOllama() { Config.setBackend(.ollama) }

    @objc private func openConfig() {
        Config.writeDefaultIfMissing()
        NSWorkspace.shared.open(URL(fileURLWithPath: Config.path))
    }

    @objc private func testConnection() {
        LLMClient.shared.convert("konnichiwa, kyou wa ii tenki desu") { result in
            DispatchQueue.main.async {
                let alert = NSAlert()
                switch result {
                case .success(let s):
                    alert.messageText = "接続OK"
                    alert.informativeText = "変換結果: \(s)"
                case .failure(let e):
                    alert.alertStyle = .warning
                    alert.messageText = "接続失敗"
                    alert.informativeText = e.localizedDescription
                }
                alert.runModal()
            }
        }
    }
}
