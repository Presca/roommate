import SwiftUI

/// Reveals `text` one character at a time. Restarts whenever `text` changes.
struct TypewriterText: View {
    let text: String
    var charDelay: Double = 0.04
    var onFinished: (() -> Void)? = nil

    @State private var shown = ""

    var body: some View {
        // Invisible full text keeps the bubble from resizing while typing.
        Text(text)
            .opacity(0)
            .overlay(alignment: .topLeading) {
                Text(shown)
            }
            .task(id: text) {
                shown = ""
                for ch in text {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(charDelay * 1_000_000_000))
                    } catch {
                        return   // view went away or text changed
                    }
                    shown.append(ch)
                }
                onFinished?()
            }
    }
}

/// A hand-drawn-looking speech bubble with a little tail at the bottom left.
struct SpeechBubble<Content: View>: View {
    var tailOnLeft = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                BubbleShape(tailOnLeft: tailOnLeft)
                    .fill(Color.white)
            )
            .overlay(
                BubbleShape(tailOnLeft: tailOnLeft)
                    .stroke(Theme.ink, lineWidth: 2)
            )
    }
}

struct BubbleShape: Shape {
    var tailOnLeft = true

    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 14
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: rect.height - tail)
        var p = Path(roundedRect: body, cornerRadius: 20, style: .continuous)
        let baseX = tailOnLeft ? body.minX + 36 : body.maxX - 36
        let dir: CGFloat = tailOnLeft ? 1 : -1
        var t = Path()
        t.move(to: CGPoint(x: baseX - 8 * dir, y: body.maxY - 1))
        t.addLine(to: CGPoint(x: baseX - 4 * dir, y: body.maxY + tail))
        t.addLine(to: CGPoint(x: baseX + 12 * dir, y: body.maxY - 1))
        t.closeSubpath()
        p.addPath(t)
        return p
    }
}
