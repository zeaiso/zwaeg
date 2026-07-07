import SwiftUI

struct ScannerScreen: View {
    let profile: UserProfile

    @State private var manualBarcode = ""
    @State private var isLoading = false
    @State private var scannedProduct: FoodProduct?
    @State private var statusMessage: String?
    /// Ignores repeat scan callbacks while a lookup or the portion sheet is active.
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    cameraArea
                    modeChips
                    manualEntry
                    if isLoading {
                        ProgressView("Suche Produkt...")
                            .tint(Color.appAccent)
                    }
                    if let statusMessage {
                        Label(statusMessage, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $scannedProduct, onDismiss: { isBusy = false }) { product in
                ProductPortionSheet(product: product)
                    .presentationDetents([.large])
            }
            .onAppear {
                if CommandLine.arguments.contains("-demo-product") {
                    scannedProduct = FoodProduct(
                        id: "demo", name: "Avocado-Toast", brand: "Znüni",
                        kcalPer100g: 320, proteinPer100g: 9, carbsPer100g: 32, fatPer100g: 18,
                        barcode: nil, source: .swissDatabase)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scanner")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(Theme.ink)
                Text("Barcode scannen, in Sekunden geloggt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var cameraArea: some View {
        ZStack {
            if BarcodeScannerView.isSupported {
                BarcodeScannerView { barcode in
                    lookup(barcode)
                }
            } else {
                LinearGradient(colors: [Color(red: 0.18, green: 0.15, blue: 0.13),
                                        Color(red: 0.28, green: 0.22, blue: 0.19)],
                               startPoint: .top, endPoint: .bottom)
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Kamera nur auf dem iPhone")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Nutze unten die manuelle Eingabe")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            ScannerFrame()
                .stroke(.white, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .frame(width: 210, height: 210)
                .shadow(color: .black.opacity(0.3), radius: 6)
        }
        .frame(height: 380)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.12), radius: 14, y: 6)
    }

    private var modeChips: some View {
        HStack(spacing: 10) {
            modeChip("barcode", "Barcode", active: true)
            modeChip("camera.fill", "Foto (bald)", active: false)
            modeChip("doc.text.viewfinder", "Label (bald)", active: false)
        }
    }

    private func modeChip(_ symbol: String, _ label: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(active ? Theme.accent : Theme.card, in: Capsule())
        .foregroundStyle(active ? Theme.onAccent : .secondary)
        .shadow(color: Theme.ink.opacity(0.04), radius: 6, y: 2)
    }

    private var manualEntry: some View {
        HStack(spacing: 10) {
            Image(systemName: "barcode")
                .foregroundStyle(.secondary)
            TextField("Barcode eingeben (z.B. 7610036010305)", text: $manualBarcode)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
            Button {
                lookup(manualBarcode)
            } label: {
                Text("Suchen")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Theme.onAccent)
            }
            .buttonStyle(.plain)
            .disabled(manualBarcode.filter(\.isNumber).count < 6 || isLoading)
            .opacity(manualBarcode.filter(\.isNumber).count < 6 ? 0.5 : 1)
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.05), radius: 8, y: 3)
    }

    private func lookup(_ barcode: String) {
        guard !isBusy else { return }
        isBusy = true
        isLoading = true
        statusMessage = nil
        Task {
            defer { isLoading = false }
            do {
                if let product = try await OpenFoodFactsClient.fetchProduct(barcode: barcode) {
                    scannedProduct = product
                    manualBarcode = ""
                } else {
                    statusMessage = "Produkt nicht gefunden. Du kannst es im Tagebuch manuell eintragen."
                    isBusy = false
                }
            } catch {
                statusMessage = error.localizedDescription
                isBusy = false
            }
        }
    }
}

/// Four corner brackets, like a camera viewfinder.
struct ScannerFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.18
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}
