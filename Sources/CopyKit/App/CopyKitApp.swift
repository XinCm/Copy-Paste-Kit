import AppKit

@main
enum CopyKitApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate(isDemo: CommandLine.arguments.contains("--demo"))
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
