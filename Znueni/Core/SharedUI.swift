import SwiftUI

// MARK: - Card container

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Detail header

/// Back button, title and optional subtitle for pushed detail pages.
struct DetailHeader: View {
    let title: String
    var subtitle: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.card, in: Circle())
                    .shadow(color: Theme.ink.opacity(0.05), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Value input rows

/// Compact row with a typeable number field: title left, value and unit right.
struct ValueField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var format: String = "%.0f"

    @FocusState private var isFocused: Bool

    private var fractionDigits: Int {
        format.contains(".1") ? 1 : 0
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("", value: clampedValue,
                      format: .number.precision(.fractionLength(0...fractionDigits)))
                .keyboardType(fractionDigits == 0 ? .numberPad : .decimalPad)
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .frame(width: 84)
                .padding(.vertical, 8)
                .background(Theme.field,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.appAccent : .clear, lineWidth: 1.5))
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 34, alignment: .leading)
        }
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { isFocused = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var clampedValue: Binding<Double> {
        Binding(
            get: { value },
            set: { newValue in
                let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                value = (clamped / step).rounded() * step
            })
    }
}

/// Large centered number input for one-question-per-screen flows.
struct BigValueField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var fractionDigits: Int = 0

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            TextField("", value: clampedValue,
                      format: .number.precision(.fractionLength(0...fractionDigits)))
                .keyboardType(fractionDigits == 0 ? .numberPad : .decimalPad)
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .frame(width: 190)
                .padding(.vertical, 10)
                .background(Theme.card,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isFocused ? Color.appAccent : Color(.systemGray4), lineWidth: 2))
            Text(unit)
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            isFocused = true
        }
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { isFocused = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var clampedValue: Binding<Double> {
        Binding(
            get: { value },
            set: { newValue in
                let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                value = (clamped / step).rounded() * step
            })
    }
}

// MARK: - Big result number

struct ResultNumber: View {
    let value: String
    let unit: String
    var color: Color = .appAccent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(unit)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
