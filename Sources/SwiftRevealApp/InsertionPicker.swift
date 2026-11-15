import SwiftUI

/// A regular button/popover keeps insertion usable without native menu tracking.
struct InsertionPicker<Choice: Hashable>: View {
    let title: String
    let symbol: String
    let choices: [Choice]
    let label: (Choice) -> String
    let action: (Choice) -> Void
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: { Label(title, systemImage: symbol) }
            .help(title)
            .accessibilityLabel(title)
            .popover(isPresented: $isPresented) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).padding(.bottom, 6)
                    ForEach(choices, id: \.self) { choice in
                        Button {
                            isPresented = false
                            action(choice)
                        } label: {
                            Text(label(choice)).frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(label(choice))
                    }
                }
                .padding(14).frame(width: 220)
            }
    }
}
