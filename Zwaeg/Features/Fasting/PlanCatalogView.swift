import SwiftUI

/// All fasting plans grouped by level; picking one sets the plan
/// for the next fast (a running fast keeps its own plan).
struct PlanCatalogView: View {
    @AppStorage("fastingPlan") private var planRaw = FastingPlan.sixteenEight.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailHeader(title: "Plan wählen".loc)
                ForEach(FastingLevel.allCases) { level in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(level.label)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(Theme.ink)
                        ForEach(FastingPlan.allCases.filter { $0.level == level }) { plan in
                            planRow(plan)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func planRow(_ plan: FastingPlan) -> some View {
        let selected = planRaw == plan.rawValue
        return Button {
            planRaw = plan.rawValue
            dismiss()
        } label: {
            Card {
                HStack(spacing: 14) {
                    EmojiOrSymbol(emoji: plan.emoji, symbol: plan.symbol, size: 30)
                        .frame(width: 52, height: 52)
                        .background(Theme.field.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.label)
                            .font(.fredoka(17, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(plan.detail)
                            .font(.fredoka(13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selected ? Color.appAccent : Color(.systemGray3))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
