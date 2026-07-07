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

// MARK: - Calorie ring

struct CalorieRingView: View {
    let consumed: Int
    let target: Int

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(consumed) / Double(target))
    }

    private var over: Bool { consumed > target }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    over ? AnyShapeStyle(Color.orange)
                         : AnyShapeStyle(AngularGradient(
                              colors: [.appAccent.opacity(0.6), .appAccent],
                              center: .center,
                              startAngle: .degrees(0),
                              endAngle: .degrees(360 * progress))),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: progress)
            VStack(spacing: 2) {
                Text("\(max(0, target - consumed))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(over ? "kcal drüber" : "kcal übrig")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
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
