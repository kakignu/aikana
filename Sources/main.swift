import Cocoa
import InputMethodKit
import Carbon

// Entry point for the AIかな input method server.
// IMKServer listens for the connection name declared in Info.plist and
// instantiates RomajiInputController (registered via @objc) for each client.

let bundle = Bundle.main

// Self-register this input source so it shows up in System Settings without
// extra steps (idempotent — harmless if already registered).
TISRegisterInputSource(bundle.bundleURL as CFURL)

let connectionName = (bundle.infoDictionary?["InputMethodConnectionName"] as? String)
    ?? "AIKana_1_Connection"

guard let server = IMKServer(name: connectionName, bundleIdentifier: bundle.bundleIdentifier) else {
    NSLog("AIKana: failed to create IMKServer for \(connectionName)")
    exit(1)
}
_ = server // keep alive

NSLog("AIKana: input method server started (\(connectionName))")
NSApplication.shared.run()
