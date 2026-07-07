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
            VStack(spacing: 16) {
                cameraArea
                manualEntry
                if isLoading {
                    ProgressView("Suche Produkt...")
                }
                if let statusMessage {
                    Label(statusMessage, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Theme.background)
            .navigationTitle("Scannen")
            .sheet(item: $scannedProduct, onDismiss: { isBusy = false }) { product in
                ProductPortionSheet(product: product)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var cameraArea: some View {
        Group {
            if BarcodeScannerView.isSupported {
                BarcodeScannerView { barcode in
                    lookup(barcode)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.on.rectangle")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Kamera nicht verfügbar")
                        .font(.headline)
                    Text("Auf dem iPhone kannst du hier Barcodes direkt scannen. Nutze unten die manuelle Eingabe.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.card)
            }
        }
        .frame(maxHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.appAccent.opacity(0.4), lineWidth: 1.5))
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
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
            .disabled(manualBarcode.filter(\.isNumber).count < 6 || isLoading)
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
