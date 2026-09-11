import SwiftUI

/// Shows one of her poses. Until you run Scripts/slice_sheets.py the
/// imagesets are empty, so we draw a friendly placeholder instead of nothing.
struct CharacterImage: View {
    let name: String

    var body: some View {
        if let ui = UIImage(named: name) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.line, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            VStack(spacing: 8) {
                Image(systemName: "face.dashed")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.soft)
                Text(name)
                    .font(.cute(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("run Scripts/slice_sheets.py\nto add her artwork")
                    .font(.cute(12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.soft)
            }
            .padding()
        }
        .aspectRatio(0.62, contentMode: .fit)
    }
}
