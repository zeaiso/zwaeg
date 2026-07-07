import SwiftUI

// MARK: - Card container

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

// MARK: - Value slider row

/// Slider with a tappable number field, so values can be typed directly.
struct ValueSlider: View {
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
        VStack(alignment: .leading, spacing: 6) {
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
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(width: 72)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? Color.appAccent : .clear, lineWidth: 1.5))
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .tint(.appAccent)
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

    /// Typed values snap to the slider's step and stay inside the range.
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
