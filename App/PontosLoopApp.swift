import SwiftUI

@main
struct PontosLoopApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
    }
}
