import SwiftUI

struct HistoryView: View {
    @Binding var scenarios: [SavedScenario]
    var restore: (InputState) -> Void

    var body: some View {
        NavigationStack {
            List {
                if scenarios.isEmpty {
                    ContentUnavailableView("Suas escolhas, guardadas",
                                           systemImage: "bookmark",
                                           description: Text("Toque em Salvar na simulação para comparar suas compras depois."))
                        .listRowBackground(Color.clear)
                }
                ForEach(scenarios) { scenario in
                    Button {
                        restore(scenario.input)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 40, height: 44)
                                .background(AppTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(scenario.name).font(.headline).foregroundStyle(.primary)
                                Text(scenario.input.mode.rawValue + " · " + scenario.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                    .accessibilityHint("Abre esta simulação. Datas antigas precisam ser atualizadas.")
                }
                .onDelete { offsets in
                    scenarios.remove(atOffsets: offsets)
                    HistoryStore.save(scenarios)
                }
            }
            .navigationTitle("Suas simulações")
            .background(AppTheme.canvas)
        }
    }
}
