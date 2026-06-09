import Cocoa
import InputMethodKit

// Entry point for the AIかな input method server.
// IMKServer listens for the connection name declared in Info.plist and
// instantiates RomajiInputController (registered via @objc) for each client.

let bundle = Bundle.main
let connectionName = (bundle.infoDictionary?["InputMethodConnectionName"] as? String)
    ?? "AIKana_1_Connection"

guard let server = IMKServer(name: connectionName, bundleIdentifier: bundle.bundleIdentifier) else {
    NSLog("AIKana: failed to create IMKServer for \(connectionName)")
    exit(1)
}
_ = server // keep alive

NSLog("AIKana: input method server started (\(connectionName))")
NSApplication.shared.run()
