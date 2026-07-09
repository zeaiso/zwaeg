import SwiftUI

struct ShoppingItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var done = false
}

/// Persisted grocery list, filled from recipe ingredients.
@Observable
final class ShoppingList {
    static let shared = ShoppingList()

    private static let key = "shoppingList"

    private(set) var items: [ShoppingItem]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let items = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            self.items = items
        } else {
            items = []
        }
    }

    func add(_ ingredients: [String]) {
        let existing = Set(items.map(\.text))
        items.append(contentsOf: ingredients.filter { !existing.contains($0) }
            .map { ShoppingItem(text: $0) })
        save()
    }

    func toggle(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].done.toggle()
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: Self.key)
    }
}

/// Munch-style grocery list sheet with tappable check circles.
struct ShoppingListView: View {
    @State private var list = ShoppingList.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if list.items.isEmpty {
                        VStack(spacing: 10) {
                            EmojiOrSymbol(emoji: "🧺", symbol: "basket", size: 44)
                            Text("Noch nichts auf der Liste".loc)
                                .font(.fredoka(15))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                    ForEach(list.items) { item in
                        Button {
                            withAnimation(.snappy(duration: 0.15)) {
                                list.toggle(item.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(item.done ? Color.appAccent : Color(.systemGray3))
                                Text(item.text)
                                    .font(.fredoka(15))
                                    .foregroundStyle(item.done ? .secondary : .primary)
                                    .strikethrough(item.done)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Einkaufsliste".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !list.items.isEmpty {
                        Button("Leeren".loc) {
                            withAnimation(.snappy(duration: 0.2)) {
                                list.clear()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
