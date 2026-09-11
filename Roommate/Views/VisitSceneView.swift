import SwiftUI

/// Her visit: she walks in sleepy, says her piece (typewriter), gets
/// frustrated, then walks out. Opened from the bedtime notification, from
/// the app at night, or from "preview her visit".
struct VisitSceneView: View {
    let stage: Stage
    let isPreview: Bool

    @EnvironmentObject private var model: RoommateModel
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case entering, talking, frustrated, thanking, leaving, gone }

    @State private var phase: Phase = .entering
    @State private var lines: [String] = []
    @State private var lineIndex = 0
    @State private var pose = "pose-peek"
    @State private var offsetX: CGFloat = -600
    @State private var bubbleVisible = false
    @State private var farewell = ""

    private var effectiveStage: Stage { stage == .none ? .sleepy : stage }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 8)

                    // bubble
                    ZStack {
                        if bubbleVisible, lineIndex < lines.count {
                            SpeechBubble {
                                TypewriterText(text: lines[lineIndex]) {
                                    lineFinished()
                                }
                                .font(.cute(21))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: geo.size.width * 0.78, alignment: .leading)
                            }
                            .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
                        }
                    }
                    .frame(minHeight: 110)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)

                    // her
                    CharacterImage(name: pose)
                        .id(pose)
                        .transition(.opacity)
                        .frame(height: geo.size.height * 0.46)
                        .offset(x: offsetX)
                        .padding(.leading, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 8)
                    footer
                }
                .padding(.bottom, 20)

                if phase == .gone {
                    goneOverlay
                }
            }
        }
        .onAppear(perform: start)
    }

    // MARK: pieces

    private var header: some View {
        HStack {
            Text(isPreview ? "preview" : RoommateLines.shieldTitle(for: effectiveStage))
                .font(.cute(16, weight: .semibold))
                .foregroundStyle(Theme.soft)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.soft)
                    .padding(10)
                    .background(Circle().fill(Theme.ink.opacity(0.06)))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .talking, .frustrated:
            VStack(spacing: 10) {
                Button(action: turnOff) {
                    Text("okay, I'll turn it off 🌙")
                        .font(.cute(19, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.skyDark, in: Capsule())
                }
                Button(action: notYet) {
                    Text("not yet...")
                        .font(.cute(16))
                        .foregroundStyle(Theme.soft)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 28)
            .transition(.opacity)
        default:
            Color.clear.frame(height: 88)
        }
    }

    private var goneOverlay: some View {
        VStack(spacing: 14) {
            Text(farewell)
                .font(.cute(20))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("close")
                    .font(.cute(17, weight: .semibold))
                    .foregroundStyle(Theme.skyDark)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
                    .background(Capsule().stroke(Theme.skyDark, lineWidth: 2))
            }
        }
        .padding(28)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(32)
        .transition(.opacity)
    }

    // MARK: choreography

    private func start() {
        lines = RoommateLines.lines(for: effectiveStage, bedtime: model.bedtimeString)
        pose = effectiveStage == .fuming ? "pose-frustrated" : "pose-peek"
        offsetX = -600
        withAnimation(.easeOut(duration: 1.1)) {
            offsetX = 0
        }
        after(1.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                pose = effectiveStage == .fuming ? "pose-frustrated" : "pose-talk"
                phase = .talking
                bubbleVisible = true
            }
        }
    }

    private func lineFinished() {
        let pause = phase == .thanking ? 0.9 : 1.2
        after(pause) {
            if lineIndex + 1 < lines.count {
                lineIndex += 1
            } else if phase == .thanking {
                leave(sayingGoodbye: "she went back to bed. sleep well ♡")
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    bubbleVisible = false
                    pose = "pose-frustrated"
                    phase = .frustrated
                }
                after(1.6) {
                    leave(sayingGoodbye: "she went back to her room, sighing.")
                }
            }
        }
    }

    private func leave(sayingGoodbye text: String) {
        farewell = text
        withAnimation(.easeInOut(duration: 0.25)) {
            bubbleVisible = false
            pose = "pose-walk"
            phase = .leaving
        }
        after(0.3) {
            withAnimation(.easeIn(duration: 1.3)) {
                offsetX = 700
            }
        }
        after(1.7) {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .gone
            }
        }
    }

    private func turnOff() {
        if !isPreview { model.comply() }
        lines = RoommateLines.thankYou()
        lineIndex = 0
        withAnimation(.easeInOut(duration: 0.3)) {
            pose = "pose-talk"
            phase = .thanking
            bubbleVisible = true
        }
    }

    private func notYet() {
        if !isPreview { model.snooze() }
        withAnimation(.easeInOut(duration: 0.3)) {
            bubbleVisible = false
            pose = "pose-frustrated"
            phase = .frustrated
        }
        after(1.0) {
            leave(sayingGoodbye: isPreview
                  ? "she left. (in a real visit she'd be back in 15 minutes.)"
                  : "she left. she'll be back in 15 minutes, and not happy about it.")
        }
    }

    private func after(_ seconds: Double, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: block)
    }
}
