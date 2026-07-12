import SwiftUI

/// The "Person" buddy: a whole cartoon person drawn in code, so the body can
/// smoothly follow the user's weight. Factor 0 is slim, 1 is maximally round.
/// headOnly renders just the face for small chip contexts.
struct BuddyCharacterView: View {
    var traits: PersonTraits
    var factor: Double = 0.35
    var pose: BuddyPose = .neutral
    var energetic: Bool = false
    var headOnly: Bool = false

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
            let f = min(max(factor, 0), 1)
            let designW = 300.0
            let u = size.width / designW
            let skin = Self.skins[traits.skin % Self.skins.count]
            let hairColor = Self.hairColors[traits.hair % Self.hairColors.count]
            let shirt = Buddy.palette[traits.shirt % Buddy.palette.count]
            let ink = Color(red: 0.13, green: 0.11, blue: 0.10)
            let pants = Color(red: 0.20, green: 0.18, blue: 0.24)
            let shoes = Color(red: 0.98, green: 0.95, blue: 0.92)

            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * u, y: y * u) }
            func rect(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double) -> CGRect {
                CGRect(x: x * u, y: y * u, width: rw * u, height: rh * u)
            }

            let headCX = 150.0
            let headCY = headOnly ? 108.0 : 92.0
            let headW = 150.0, headH = 142.0
            let cheek = 1.0 + 0.10 * f
            let hw = headW * cheek

            // ---- body (skipped in chip mode) ----
            if !headOnly {
                let shoulderY = 192.0
                let hemY = 316.0
                let shoulderHalf = 56.0 + 10.0 * f
                let waistHalf = 50.0 + 38.0 * f
                let hipHalf = 47.0 + 27.0 * f
                let legW = 27.0 + 5.0 * f, legGap = 14.0
                let legTop = hemY - 8, legBottom = 392.0
                let armW = 21.0
                let handR = 13.0

                for side in [-1.0, 1.0] {
                    let x = 150 + side * (legGap / 2 + legW / 2)
                    var leg = Path()
                    leg.addRoundedRect(in: rect(x - legW / 2, legTop, legW, legBottom - legTop),
                                       cornerSize: CGSize(width: 12 * u, height: 12 * u))
                    ctx.fill(leg, with: .color(pants))
                    var shoe = Path()
                    shoe.addRoundedRect(in: rect(x - legW / 2 - 6, legBottom - 8, legW + 16, 24),
                                        cornerSize: CGSize(width: 12 * u, height: 12 * u))
                    ctx.fill(shoe, with: .color(shoes))
                }

                var torso = Path()
                torso.move(to: pt(150 - shoulderHalf, shoulderY + 14))
                torso.addCurve(to: pt(150 - waistHalf, 272),
                               control1: pt(150 - shoulderHalf - 4, shoulderY + 40),
                               control2: pt(150 - waistHalf - 2, 244))
                torso.addCurve(to: pt(150 - hipHalf, hemY),
                               control1: pt(150 - waistHalf + 1, 294),
                               control2: pt(150 - hipHalf - 3, hemY - 10))
                torso.addQuadCurve(to: pt(150 + hipHalf, hemY),
                                   control: pt(150, hemY + 10 + 14 * f))
                torso.addCurve(to: pt(150 + waistHalf, 272),
                               control1: pt(150 + hipHalf + 3, hemY - 10),
                               control2: pt(150 + waistHalf - 1, 294))
                torso.addCurve(to: pt(150 + shoulderHalf, shoulderY + 14),
                               control1: pt(150 + waistHalf + 2, 244),
                               control2: pt(150 + shoulderHalf + 4, shoulderY + 40))
                torso.addQuadCurve(to: pt(150 + shoulderHalf - 26, shoulderY - 6),
                                   control: pt(150 + shoulderHalf, shoulderY - 8))
                torso.addLine(to: pt(150 - shoulderHalf + 26, shoulderY - 6))
                torso.addQuadCurve(to: pt(150 - shoulderHalf, shoulderY + 14),
                                   control: pt(150 - shoulderHalf, shoulderY - 8))
                torso.closeSubpath()
                ctx.fill(torso, with: .linearGradient(
                    Gradient(colors: [shirt.opacity(0.85), shirt]),
                    startPoint: pt(90, shoulderY), endPoint: pt(210, hemY)))

                // arms: hanging, or raised in a cheer on active days
                for side in [-1.0, 1.0] {
                    let shoulderX = 150 + side * (shoulderHalf - 6)
                    var arm = Path()
                    let handX: Double
                    let handY: Double
                    if energetic {
                        handX = 150 + side * (shoulderHalf + 34)
                        handY = 176.0
                        arm.move(to: pt(shoulderX, shoulderY + 12))
                        arm.addQuadCurve(to: pt(handX, handY + 10),
                                         control: pt(150 + side * (shoulderHalf + 34), 224))
                    } else {
                        handX = 150 + side * (waistHalf + armW / 2 + 5)
                        handY = 306.0
                        arm.move(to: pt(shoulderX, shoulderY + 10))
                        arm.addQuadCurve(to: pt(handX, handY - 8),
                                         control: pt(150 + side * (shoulderHalf + 8 + 16 * f), 252))
                    }
                    ctx.stroke(arm, with: .color(shirt),
                               style: StrokeStyle(lineWidth: armW * u, lineCap: .round))
                    var hand = Path()
                    hand.addEllipse(in: rect(handX - handR, handY - handR, handR * 2, handR * 2))
                    ctx.fill(hand, with: .color(skin.0))
                }

                var neck = Path()
                neck.addRoundedRect(in: rect(150 - 15, 150, 30, 50),
                                    cornerSize: CGSize(width: 10 * u, height: 10 * u))
                ctx.fill(neck, with: .color(skin.1))
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

            // long hair falls behind the ears down the sides
            if traits.style == 1 {
                var mane = Path()
                mane.addRoundedRect(in: rect(headCX - hw / 2 - 8, headCY - headH / 2 + 10,
                                             hw + 16, headH * 0.94),
                                    cornerSize: CGSize(width: 56 * u, height: 60 * u))
                ctx.fill(mane, with: .color(hairColor))
                var faceAgain = Path()
                faceAgain.addRoundedRect(in: rect(headCX - hw / 2 + 6, headCY - headH / 2 + 14,
                                                  hw - 12, headH - 8),
                                         cornerSize: CGSize(width: 54 * u, height: 58 * u))
                ctx.fill(faceAgain, with: .color(skin.0))
            }

            // hair cap (styles 0 short, 1 long, 2 bun; 3 is bald)
            if traits.style != 3 {
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

            if traits.style == 2 {
                var bun = Path()
                bun.addEllipse(in: rect(headCX - 22, headCY - headH / 2 - 26, 44, 36))
                ctx.fill(bun, with: .color(hairColor))
            }

            // ---- face by pose ----
            let sleeping = pose == .sleeping
            for side in [-1.0, 1.0] {
                if sleeping {
                    var lid = Path()
                    lid.move(to: pt(headCX + side * 22, headCY + 8))
                    lid.addQuadCurve(to: pt(headCX + side * 38, headCY + 8),
                                     control: pt(headCX + side * 30, headCY + 15))
                    ctx.stroke(lid, with: .color(ink),
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

            switch pose {
            case .happy, .party:
                // open smile
                var mouth = Path()
                mouth.move(to: pt(headCX - 16, headCY + 32))
                mouth.addQuadCurve(to: pt(headCX + 16, headCY + 32), control: pt(headCX, headCY + 54))
                mouth.closeSubpath()
                ctx.fill(mouth, with: .color(ink))
            case .over:
                var mouth = Path()
                mouth.move(to: pt(headCX - 11, headCY + 38))
                mouth.addLine(to: pt(headCX + 11, headCY + 38))
                ctx.stroke(mouth, with: .color(ink),
                           style: StrokeStyle(lineWidth: 5.5 * u, lineCap: .round))
            default:
                var smile = Path()
                smile.move(to: pt(headCX - 14, headCY + 34))
                smile.addQuadCurve(to: pt(headCX + 14, headCY + 34), control: pt(headCX, headCY + 48))
                ctx.stroke(smile, with: .color(ink),
                           style: StrokeStyle(lineWidth: 5.5 * u, lineCap: .round))
            }

            let blush = Color(red: 1.0, green: 0.62, blue: 0.52).opacity(0.55)
            for side in [-1.0, 1.0] {
                var cheekDot = Path()
                cheekDot.addEllipse(in: rect(headCX + side * 48 - 9, headCY + 26, 18, 12))
                ctx.fill(cheekDot, with: .color(blush))
            }

            if !headOnly && f > 0.55 {
                var chin = Path()
                chin.move(to: pt(headCX - 22, headCY + headH / 2 - 6))
                chin.addQuadCurve(to: pt(headCX + 22, headCY + headH / 2 - 6),
                                  control: pt(headCX, headCY + headH / 2 + 6))
                ctx.stroke(chin, with: .color(skin.1.opacity(0.5 * f)),
                           style: StrokeStyle(lineWidth: 4 * u, lineCap: .round))
            }
        }
        .aspectRatio(headOnly ? 300.0 / 216.0 : 300.0 / 430.0, contentMode: .fit)
    }
}
