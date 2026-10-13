import SwiftUI

@main
struct CompraClaraApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
    }
}
