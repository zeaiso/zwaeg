import SwiftUI
import SwiftData
import AVFoundation

/// Full-screen dark scanner in the Munch style: coral viewfinder brackets,
/// glowing scan line, mode tabs and camera controls.
struct ScannerScreen: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context

    @State private var manualBarcode = ""
    @State private var isLoading = false
    @State private var scannedProduct: FoodProduct?
    @State private var statusMessage: String?
    /// Barcode of the last lookup that came back empty; enables creating an own product.
    @State private var unknownBarcode: String?
    @State private var showCustomForm = false
    @State private var pendingProduct: FoodProduct?
    @State private var showManual = false
    @State private var torchOn = false
    @State private var scanLinePulse = false
    /// Ignores repeat scan callbacks while a lookup or the portion sheet is active.
    @State private var isBusy = false
    @State private var mode: ScanMode = .barcode
    @State private var camera = ScannerCamera()
    /// Values read off a nutrition table; prefill the custom food form.
    @State private var labelFacts: NutritionFacts?

    enum ScanMode {
        case barcode, label
    }

    private let bracketColor = Color(red: 1.0, green: 0.54, blue: 0.36)

    var body: some View {
        ZStack {
            cameraBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                viewfinder
                statusChip
                    .padding(.top, 22)
                if unknownBarcode != nil {
                    createCustomButton
                        .padding(.top, 12)
                }
                Spacer()
                if showManual {
                    manualEntry
                        .padding(.bottom, 14)
                }
                modeTabs
                    .padding(.bottom, 18)
                controls
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .sheet(item: $scannedProduct, onDismiss: { isBusy = false }) { product in
            ProductPortionSheet(product: product)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCustomForm, onDismiss: {
            labelFacts = nil
            if let product = pendingProduct {
                pendingProduct = nil
                unknownBarcode = nil
                scannedProduct = product
            } else {
                isBusy = false
            }
        }) {
            CustomFoodForm(barcode: unknownBarcode, prefill: labelFacts) { pendingProduct = $0 }
                .presentationDetents([.large])
        }
        .onAppear {
            scanLinePulse = true
            if let flagIndex = LaunchArgs.all.firstIndex(of: "-demo-scan"),
               LaunchArgs.all.indices.contains(flagIndex + 1) {
                lookup(LaunchArgs.all[flagIndex + 1])
            }
            if LaunchArgs.all.contains("-open-custom-form") {
                unknownBarcode = "4041234567890"
                showCustomForm = true
            }
            if LaunchArgs.all.contains("-demo-label") {
                mode = .label
                labelFacts = NutritionLabelParser.parse(lines: [
                    "Nährwerte pro 100 g", "Energie 1520 kJ / 364 kcal",
                    "Fett 12,5 g", "davon gesättigte Fettsäuren 5,2 g",
                    "Kohlenhydrate 48 g", "davon Zucker 22 g",
                    "Eiweiß 9,8 g", "Salz 0,4 g",
                ])
                showCustomForm = true
            }
            if LaunchArgs.all.contains("-demo-product") {
                scannedProduct = FoodProduct(
                    id: "demo", name: "Avocado-Toast", brand: "Zwäg",
                    kcalPer100g: 320, proteinPer100g: 9, carbsPer100g: 32, fatPer100g: 18,
                    barcode: nil, source: .swissDatabase)
            }
        }
    }

    // MARK: - Camera background

    @ViewBuilder
    private var cameraBackground: some View {
        if BarcodeScannerView.isSupported {
            BarcodeScannerView(camera: camera) { barcode in
                guard mode == .barcode else { return }
                lookup(barcode)
            }
        } else {
            LinearGradient(colors: [Color(red: 0.11, green: 0.09, blue: 0.08),
                                    Color(red: 0.17, green: 0.13, blue: 0.11)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Scanner")
                .font(.fredoka(17, .semibold))
                .foregroundStyle(.white)
            HStack {
                Button {
                    TabRouter.shared.selection = 0
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.fredoka(15, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        ZStack {
            RoundedScannerFrame()
                .stroke(bracketColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            Capsule()
                .fill(bracketColor)
                .frame(height: 3.5)
                .padding(.horizontal, 26)
                .shadow(color: bracketColor.opacity(0.9), radius: 8)
                .shadow(color: bracketColor.opacity(0.5), radius: 16)
                .opacity(scanLinePulse ? 1.0 : 0.35)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                           value: scanLinePulse)
        }
        .frame(width: 250, height: 250)
    }

    private var statusChip: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            } else {
                Circle()
                    .fill(bracketColor)
                    .frame(width: 8, height: 8)
            }
            Text(chipText)
                .font(.fredoka(13, .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var chipText: String {
        if isLoading {
            return mode == .label ? "Lese Nährwerte...".loc : "Suche Produkt...".loc
        }
        if let statusMessage { return statusMessage }
        guard BarcodeScannerView.isSupported else {
            return "Kamera nur auf dem iPhone. Barcode manuell eingeben.".loc
        }
        return mode == .label
            ? "Richte die Kamera auf die Nährwerttabelle".loc
            : "Richte die Kamera auf einen Barcode".loc
    }

    // MARK: - Mode tabs

    private var modeTabs: some View {
        HStack(spacing: 26) {
            modeTab("Barcode", target: .barcode)
            modeTab("Label".loc, target: .label)
        }
        .font(.fredoka(15, .semibold))
    }

    private func modeTab(_ title: String, target: ScanMode) -> some View {
        Button {
            withAnimation(.snappy) { mode = target }
            resetScanner()
        } label: {
            Text(title)
                .foregroundStyle(mode == target ? bracketColor : .white.opacity(0.45))
                .fontWeight(mode == target ? .bold : .semibold)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack {
            controlButton(symbol: torchOn ? "bolt.fill" : "bolt", active: torchOn) {
                toggleTorch()
            }
            Spacer()
            Button {
                if mode == .label {
                    captureLabel()
                } else if BarcodeScannerView.isSupported {
                    resetScanner()
                } else {
                    withAnimation(.snappy) { showManual = true }
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.35), lineWidth: 4)
                        .frame(width: 64, height: 64)
                    Circle()
                        .fill(.white)
                        .frame(width: 52, height: 52)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            controlButton(symbol: "arrow.clockwise", active: false) {
                resetScanner()
            }
        }
        .padding(.horizontal, 26)
    }

    private func controlButton(symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.fredoka(17, .semibold))
                .foregroundStyle(active ? bracketColor : .white)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manual entry (fallback, dark style)

    private var manualEntry: some View {
        HStack(spacing: 10) {
            Image(systemName: "barcode")
                .foregroundStyle(.white.opacity(0.6))
            TextField("", text: $manualBarcode,
                      prompt: Text("Barcode eingeben (z.B. 7610036010305)".loc)
                          .foregroundStyle(.white.opacity(0.45)))
                .keyboardType(.numberPad)
                .foregroundStyle(.white)
            Button {
                lookup(manualBarcode)
            } label: {
                Text("Suchen".loc)
                    .font(.fredoka(15, .semibold))
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
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private var createCustomButton: some View {
        Button {
            showCustomForm = true
        } label: {
            Label("Eigenes Produkt erstellen".loc, systemImage: "plus")
                .font(.fredoka(14, .semibold))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func resetScanner() {
        statusMessage = nil
        isBusy = false
        manualBarcode = ""
        unknownBarcode = nil
    }

    /// Label mode: photograph the nutrition table, OCR it on device and
    /// open the custom food form prefilled with the recognized values.
    private func captureLabel() {
        guard !isBusy, !isLoading else { return }
        isLoading = true
        statusMessage = nil
        Task {
            defer { isLoading = false }
            guard let image = await camera.capturePhoto() else {
                statusMessage = "Keine Nährwerte erkannt. Geh näher ran.".loc
                return
            }
            let lines = await NutritionLabelParser.recognizeLines(in: image)
            let facts = NutritionLabelParser.parse(lines: lines)
            if facts.isUsable {
                labelFacts = facts
                showCustomForm = true
            } else {
                statusMessage = "Keine Nährwerte erkannt. Geh näher ran.".loc
            }
        }
    }

    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchOn ? .off : .on
            device.unlockForConfiguration()
            torchOn.toggle()
        } catch {
            // Torch stays off; nothing to surface.
        }
    }

    private func lookup(_ barcode: String) {
        guard !isBusy else { return }
        isBusy = true
        isLoading = true
        statusMessage = nil
        unknownBarcode = nil

        // Own products win over the network lookup.
        let digits = barcode.filter(\.isNumber)
        let customPredicate = #Predicate<CustomFood> { $0.barcode == digits }
        if let match = try? context.fetch(FetchDescriptor(predicate: customPredicate)).first {
            isLoading = false
            scannedProduct = match.asProduct
            manualBarcode = ""
            return
        }

        // Then products this phone has scanned before; instant and offline.
        let cachePredicate = #Predicate<CachedProduct> { $0.barcode == digits }
        if let cached = try? context.fetch(FetchDescriptor(predicate: cachePredicate)).first {
            isLoading = false
            scannedProduct = cached.asProduct
            manualBarcode = ""
            return
        }

        Task {
            defer { isLoading = false }
            do {
                if let product = try await OpenFoodFactsClient.fetchProduct(barcode: barcode) {
                    context.insert(CachedProduct(product: product, barcode: digits))
                    scannedProduct = product
                    manualBarcode = ""
                } else {
                    statusMessage = "Produkt nicht gefunden. Trage es im Tagebuch manuell ein.".loc
                    unknownBarcode = digits
                    isBusy = false
                }
            } catch {
                statusMessage = error.localizedDescription
                isBusy = false
            }
        }
    }
}

/// Corner brackets with rounded corners, like a camera viewfinder.
struct RoundedScannerFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.16
        let radius = min(rect.width, rect.height) * 0.10
        var path = Path()

        // Top left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                    radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + radius + length, y: rect.minY))

        // Top right
        path.move(to: CGPoint(x: rect.maxX - radius - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                    radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + radius + length))

        // Bottom right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - radius - length, y: rect.maxY))

        // Bottom left
        path.move(to: CGPoint(x: rect.minX + radius + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius - length))

        return path
    }
}
