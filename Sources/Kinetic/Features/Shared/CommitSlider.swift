import SwiftUI

/// Shows its value while being dragged and only changes the real setting on release.
struct CommitSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var format = "%.0f"
    var minimumSymbol: String?
    var maximumSymbol: String?

    @State private var draft: Double?

    var body: some View {
        HStack {
            Slider(
                value: Binding(get: { draft ?? value }, set: { draft = $0 }),
                in: range,
                step: step
            ) {
                EmptyView()
            } minimumValueLabel: {
                if let minimumSymbol {
                    Image(systemName: minimumSymbol)
                }
            } maximumValueLabel: {
                if let maximumSymbol {
                    Image(systemName: maximumSymbol)
                }
            } onEditingChanged: { isEditing in
                guard !isEditing, let draft else { return }
                value = draft
                self.draft = nil
            }
            .labelsHidden()

            Text(String(format: format, draft ?? value))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }
}
