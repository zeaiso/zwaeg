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
            .shadow(color: Theme.shadow.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Detail header

/// Back button, title and optional subtitle for pushed detail pages.
struct DetailHeader: View {
    let title: String
    var subtitle: String?
    var showsBack = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            if showsBack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 38, height: 38)
                        .background(Theme.card, in: Circle())
                        .shadow(color: Theme.shadow.opacity(0.05), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.fredoka(22, .semibold))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.fredoka(13))
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
                .font(.fredoka(15))
                .foregroundStyle(.secondary)
            Spacer()
            TextField("", value: clampedValue,
                      format: .number.precision(.fractionLength(0...fractionDigits)))
                .keyboardType(fractionDigits == 0 ? .numberPad : .decimalPad)
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .font(.fredoka(19, .semibold))
                .frame(width: 84)
                .padding(.vertical, 8)
                .background(Theme.field,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.appAccent : .clear, lineWidth: 1.5))
            Text(unit)
                .font(.fredoka(15))
                .foregroundStyle(.secondary)
                .frame(minWidth: 34, alignment: .leading)
        }
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig".loc) { isFocused = false }
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
                .font(.fredoka(54, .semibold))
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
                    Button("Fertig".loc) { isFocused = false }
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

// MARK: - Calculation sources

/// A scientific reference backing a health calculation, rendered as a tappable link.
/// Names are bibliographic and stay untranslated.
struct SourceCitation: Identifiable {
    let name: String
    let urlString: String
    var id: String { urlString }
}

/// Citations for the medical formulas in CalorieMath (App Review Guideline 1.4.1).
enum CalculationSources {
    static let bmi = [
        SourceCitation(name: "WHO · Obesity and overweight",
                       urlString: "https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight"),
    ]
    static let calorieNeeds = [
        SourceCitation(name: "Mifflin & St Jeor 1990 · Am J Clin Nutr",
                       urlString: "https://pubmed.ncbi.nlm.nih.gov/2305711/"),
        SourceCitation(name: "FAO/WHO/UNU 2004 · Human Energy Requirements",
                       urlString: "https://www.fao.org/4/y5686e/y5686e00.htm"),
    ]
    static let idealWeight = [
        SourceCitation(name: "Pai & Paloucek 2000 · Ann Pharmacother",
                       urlString: "https://pubmed.ncbi.nlm.nih.gov/10981254/"),
    ]
    static let calorieBurn = [
        SourceCitation(name: "Ainsworth et al. 2011 · Compendium of Physical Activities",
                       urlString: "https://pubmed.ncbi.nlm.nih.gov/21681120/"),
    ]
    static let all = bmi + calorieNeeds + idealWeight + calorieBurn
}

/// Card listing the scientific sources of a calculation, with a short intro
/// naming the formula and a standing "not medical advice" note.
struct SourcesCard: View {
    let intro: String
    let sources: [SourceCitation]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Quellen".loc, systemImage: "text.book.closed.fill")
                    .font(.fredoka(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(intro)
                    .font(.fredoka(13))
                    .foregroundStyle(.secondary)
                ForEach(sources) { source in
                    if let url = URL(string: source.urlString) {
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "link")
                                    .font(.fredoka(12, .semibold))
                                    .foregroundStyle(Color.appAccent)
                                    .frame(width: 30, height: 30)
                                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                                Text(source.name)
                                    .font(.fredoka(14, .medium))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.fredoka(12, .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                Text("Richtwerte für gesunde Erwachsene – keine medizinische Beratung.".loc)
                    .font(.fredoka(11))
                    .foregroundStyle(.secondary)
            }
        }
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
                .font(.fredoka(42, .semibold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(unit)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
