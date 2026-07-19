import SwiftUI

/// Concrete look of the drawn person buddy, derived from PersonTraits
/// (palette indices). Only the head is drawn — the whole-body weight figure
/// retired when progress photos took its job.
struct PersonLook: Equatable {
    enum Glasses { case none, clear, sun }
    enum Eyes { case normal, happy, wink, closed }
    enum Mouth { case smile, open, flat, sad, tongue }

    var skin: Color
    var skinShade: Color
    var hair: Color
    var style: Int          // 0 short, 1 long, 2 bun, 3 bald, 4 hat
    var mustache = false
    var beard = false
    var glasses: Glasses = .none
    var eyes: Eyes = .normal
    var mouth: Mouth = .smile

    init(traits: PersonTraits) {
        let pair = BuddyCharacterView.skins[traits.skin % BuddyCharacterView.skins.count]
        skin = pair.0
        skinShade = pair.1
        hair = BuddyCharacterView.hairColors[traits.hair % BuddyCharacterView.hairColors.count]
        style = traits.style
    }
}

/// The drawn person buddy's head, used as the chip for the "person" kind.
struct BuddyCharacterView: View {
    var look: PersonLook

    init(traits: PersonTraits) {
        self.look = PersonLook(traits: traits)
    }

    static let skins: [(Color, Color)] = [
        (Color(red: 0.99, green: 0.87, blue: 0.75), Color(red: 0.93, green: 0.76, blue: 0.61)),
        (Color(red: 0.95, green: 0.76, blue: 0.60), Color(red: 0.89, green: 0.66, blue: 0.49)),
        (Color(red: 0.85, green: 0.64, blue: 0.45), Color(red: 0.76, green: 0.53, blue: 0.36)),
        (Color(red: 0.62, green: 0.42, blue: 0.28), Color(red: 0.52, green: 0.33, blue: 0.21)),
        (Color(red: 0.42, green: 0.28, blue: 0.20), Color(red: 0.33, green: 0.21, blue: 0.14)),
    ]

    static let hairColors: [Color] = [
        Color(red: 0.35, green: 0.24, blue: 0.16),
        Color(red: 0.13, green: 0.11, blue: 0.10),
        Color(red: 0.62, green: 0.44, blue: 0.24),
        Color(red: 0.85, green: 0.65, blue: 0.32),
        Color(red: 0.72, green: 0.30, blue: 0.18),
        Color(red: 0.62, green: 0.62, blue: 0.64),
    ]

    static let styleCount = 4   // 0 short, 1 long, 2 bun, 3 bald
    static let shirtCount = 6   // Buddy.palette

    var body: some View {
        Canvas { ctx, size in
            let designW = 300.0
            let u = size.width / designW
            let skin = (look.skin, look.skinShade)
            let hairColor = look.hair
            let ink = Color(red: 0.13, green: 0.11, blue: 0.10)

            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * u, y: y * u) }
            func rect(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double) -> CGRect {
                CGRect(x: x * u, y: y * u, width: rw * u, height: rh * u)
            }

            let headCX = 150.0
            let headCY = 108.0
            let headW = 150.0, headH = 142.0
            let hw = headW

            // long hair: strands behind the head falling to shoulder height,
            // drawn first so the face stays free and no hood forms
            if look.style == 1 {
                for side in [-1.0, 1.0] {
                    let x = side < 0 ? headCX - hw / 2 - 12 : headCX + hw / 2 - 24
                    var strand = Path()
                    strand.addRoundedRect(in: rect(x, headCY - 36, 36, headH / 2 + 100),
                                          cornerSize: CGSize(width: 17 * u, height: 17 * u))
                    ctx.fill(strand, with: .color(hairColor))
                }
            }

            // ---- head ----
            var head = Path()
            head.addRoundedRect(in: rect(headCX - hw / 2, headCY - headH / 2, hw, headH),
                                cornerSize: CGSize(width: 62 * u, height: 66 * u))
            ctx.fill(head, with: .color(skin.0))

            for side in [-1.0, 1.0] {
                var ear = Path()
                ear.addEllipse(in: rect(headCX + side * hw / 2 - 10, headCY - 4, 20, 26))
                ctx.fill(ear, with: .color(skin.0))
            }

            // hair cap (styles 0 short, 1 long, 2 bun; 3 is bald, 4 wears a hat)
            if look.style != 3 && look.style != 4 {
                var hairPath = Path()
                hairPath.move(to: pt(headCX - hw / 2 + 2, headCY - 8))
                hairPath.addQuadCurve(to: pt(headCX, headCY - headH / 2 - 8),
                                      control: pt(headCX - hw / 2 - 6, headCY - headH / 2 + 2))
                hairPath.addQuadCurve(to: pt(headCX + hw / 2 - 2, headCY - 8),
                                      control: pt(headCX + hw / 2 + 6, headCY - headH / 2 + 2))
                hairPath.addQuadCurve(to: pt(headCX + hw / 2 - 16, headCY - 30),
                                      control: pt(headCX + hw / 2 - 4, headCY - 26))
                hairPath.addQuadCurve(to: pt(headCX - hw / 2 + 16, headCY - 30),
                                      control: pt(headCX, headCY - 58))
                hairPath.addQuadCurve(to: pt(headCX - hw / 2 + 2, headCY - 8),
                                      control: pt(headCX - hw / 2 + 4, headCY - 26))
                hairPath.closeSubpath()
                ctx.fill(hairPath, with: .color(hairColor))
            }

            if look.style == 2 {
                var bun = Path()
                bun.addEllipse(in: rect(headCX - 22, headCY - headH / 2 - 26, 44, 36))
                ctx.fill(bun, with: .color(hairColor))
            }

            // beanie for all hat-like avatar tops (their color is not stored)
            if look.style == 4 {
                let hat = Color(red: 0.32, green: 0.36, blue: 0.44)
                var dome = Path()
                dome.addRoundedRect(in: rect(headCX - hw / 2 - 4, headCY - headH / 2 - 14,
                                             hw + 8, 52),
                                    cornerSize: CGSize(width: 40 * u, height: 40 * u))
                ctx.fill(dome, with: .color(hat))
                var band = Path()
                band.addRoundedRect(in: rect(headCX - hw / 2 - 7, headCY - headH / 2 + 26,
                                             hw + 14, 17),
                                    cornerSize: CGSize(width: 9 * u, height: 9 * u))
                ctx.fill(band, with: .color(hat.opacity(0.75)))
            }

            if look.beard {
                // crescent hugging the jaw: outer edge along the chin,
                // inner edge arcs above the mouth, which stays visible on top
                var beardPath = Path()
                beardPath.move(to: pt(headCX - hw / 2 + 14, headCY + 16))
                beardPath.addQuadCurve(to: pt(headCX, headCY + headH / 2 + 8),
                                       control: pt(headCX - hw / 2 + 10, headCY + headH / 2 + 4))
                beardPath.addQuadCurve(to: pt(headCX + hw / 2 - 14, headCY + 16),
                                       control: pt(headCX + hw / 2 - 10, headCY + headH / 2 + 4))
                beardPath.addQuadCurve(to: pt(headCX, headCY + 24),
                                       control: pt(headCX + hw / 2 - 26, headCY + 26))
                beardPath.addQuadCurve(to: pt(headCX - hw / 2 + 14, headCY + 16),
                                       control: pt(headCX - hw / 2 + 26, headCY + 26))
                beardPath.closeSubpath()
                ctx.fill(beardPath, with: .color(hairColor))
            }

            // ---- face ----
            for side in [-1.0, 1.0] {
                let lidDown = look.eyes == .closed
                let arcEye = !lidDown && (look.eyes == .happy || (look.eyes == .wink && side < 0))
                if lidDown {
                    var lid = Path()
                    lid.move(to: pt(headCX + side * 22, headCY + 8))
                    lid.addQuadCurve(to: pt(headCX + side * 38, headCY + 8),
                                     control: pt(headCX + side * 30, headCY + 15))
                    ctx.stroke(lid, with: .color(ink),
                               style: StrokeStyle(lineWidth: 5 * u, lineCap: .round))
                } else if arcEye {
                    // happy or winking eye: an upward arc
                    var arc = Path()
                    arc.move(to: pt(headCX + side * 22, headCY + 12))
                    arc.addQuadCurve(to: pt(headCX + side * 38, headCY + 12),
                                     control: pt(headCX + side * 30, headCY + 1))
                    ctx.stroke(arc, with: .color(ink),
                               style: StrokeStyle(lineWidth: 5 * u, lineCap: .round))
                } else {
                    var eye = Path()
                    eye.addEllipse(in: rect(headCX + side * 30 - 7, headCY + 2, 14, 16))
                    ctx.fill(eye, with: .color(ink))
                    var glint = Path()
                    glint.addEllipse(in: rect(headCX + side * 30 - 4, headCY + 4, 5, 5))
                    ctx.fill(glint, with: .color(.white.opacity(0.9)))
                }
                var brow = Path()
                brow.move(to: pt(headCX + side * 22, headCY - 14))
                brow.addQuadCurve(to: pt(headCX + side * 40, headCY - 12),
                                  control: pt(headCX + side * 31, headCY - 20))
                ctx.stroke(brow, with: .color(hairColor),
                           style: StrokeStyle(lineWidth: 5 * u, lineCap: .round))
            }

            switch look.mouth {
            case .open:
                var mouth = Path()
                mouth.move(to: pt(headCX - 15, headCY + 33))
                mouth.addQuadCurve(to: pt(headCX + 15, headCY + 33),
                                   control: pt(headCX, headCY + 52))
                mouth.closeSubpath()
                ctx.fill(mouth, with: .color(ink))
            case .flat:
                var mouth = Path()
                mouth.move(to: pt(headCX - 11, headCY + 38))
                mouth.addLine(to: pt(headCX + 11, headCY + 38))
                ctx.stroke(mouth, with: .color(ink),
                           style: StrokeStyle(lineWidth: 5.5 * u, lineCap: .round))
            case .sad:
                var mouth = Path()
                mouth.move(to: pt(headCX - 12, headCY + 42))
                mouth.addQuadCurve(to: pt(headCX + 12, headCY + 42),
                                   control: pt(headCX, headCY + 32))
                ctx.stroke(mouth, with: .color(ink),
                           style: StrokeStyle(lineWidth: 5.5 * u, lineCap: .round))
            case .tongue:
                var smile = Path()
                smile.move(to: pt(headCX - 14, headCY + 34))
                smile.addQuadCurve(to: pt(headCX + 14, headCY + 34),
                                   control: pt(headCX, headCY + 48))
                ctx.stroke(smile, with: .color(ink),
                           style: StrokeStyle(lineWidth: 5.5 * u, lineCap: .round))
                var tongue = Path()
                tongue.addEllipse(in: rect(headCX - 2, headCY + 38, 14, 12))
                ctx.fill(tongue, with: .color(Color(red: 1.0, green: 0.5, blue: 0.5)))
            case .smile:
                var smile = Path()
                smile.move(to: pt(headCX - 14, headCY + 34))
                smile.addQuadCurve(to: pt(headCX + 14, headCY + 34),
                                   control: pt(headCX, headCY + 48))
                ctx.stroke(smile, with: .color(ink),
                           style: StrokeStyle(lineWidth: 5.5 * u, lineCap: .round))
            }

            if look.glasses != .none {
                for side in [-1.0, 1.0] {
                    var lens = Path()
                    lens.addEllipse(in: rect(headCX + side * 30 - 15, headCY - 5, 30, 30))
                    if look.glasses == .sun {
                        ctx.fill(lens, with: .color(ink.opacity(0.85)))
                    }
                    ctx.stroke(lens, with: .color(ink),
                               style: StrokeStyle(lineWidth: 4 * u))
                }
                var bridge = Path()
                bridge.move(to: pt(headCX - 15, headCY + 8))
                bridge.addLine(to: pt(headCX + 15, headCY + 8))
                ctx.stroke(bridge, with: .color(ink),
                           style: StrokeStyle(lineWidth: 4 * u, lineCap: .round))
            }

            if look.mustache {
                for side in [-1.0, 1.0] {
                    var whisker = Path()
                    whisker.move(to: pt(headCX + side * 1, headCY + 26))
                    whisker.addQuadCurve(to: pt(headCX + side * 24, headCY + 19),
                                         control: pt(headCX + side * 13, headCY + 31))
                    ctx.stroke(whisker, with: .color(hairColor),
                               style: StrokeStyle(lineWidth: 8.5 * u, lineCap: .round))
                }
            }

            let blush = Color(red: 1.0, green: 0.62, blue: 0.52).opacity(0.55)
            for side in [-1.0, 1.0] where !look.beard {
                var cheekDot = Path()
                cheekDot.addEllipse(in: rect(headCX + side * 48 - 9, headCY + 26, 18, 12))
                ctx.fill(cheekDot, with: .color(blush))
            }
        }
        .aspectRatio(300.0 / 216.0, contentMode: .fit)
    }
}
