import SwiftUI

struct AppRootView: View {
    @State private var input = InputState.restore()
    @State private var scenarios = HistoryStore.load()
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            CalculatorView(input: $input, scenarios: $scenarios,
                           openAssistant: { selection = 1 }, openHistory: { selection = 2 })
                .tabItem { Label("Simular", systemImage: "slider.horizontal.3") }.tag(0)
            AssistantView(input: input)
                .tabItem { Label("Noah", systemImage: "bubble.left.and.bubble.right") }.tag(1)
            HistoryView(scenarios: $scenarios) { saved in
                input = saved
                selection = 0
            }
            .tabItem { Label("Salvos", systemImage: "bookmark") }.tag(2)
        }
        .preferredColorScheme(.dark)
        .tint(AppTheme.accent)
        .onChange(of: input) { _, value in value.persist() }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 720)
        #endif
    }
}
