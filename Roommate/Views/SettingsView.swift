import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject private var model: RoommateModel
    @Environment(\.dismiss) private var dismiss

    @State private var showPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var isWorking = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    onSwitch
                    times
                    apps
                    danger
                    about
                }
                .padding(20)
            }
            .background(Theme.cream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("settings")
                        .font(.cute(20, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                        .font(.cute(16, weight: .semibold))
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $pickerSelection)
            .onChange(of: showPicker) { open in
                if !open { model.updateSelection(pickerSelection) }
            }
            .onAppear { pickerSelection = model.selection }
            .alert("reset her mood?", isPresented: $confirmReset) {
                Button("reset", role: .destructive) { model.resetMood() }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("happiness, frustration and the night log go back to the start.")
            }
        }
        .tint(Theme.skyDark)
    }

    private var onSwitch: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { model.isEnabled },
                set: { on in
                    isWorking = true
                    Task {
                        await model.setEnabled(on)
                        isWorking = false
                    }
                }
            )) {
                HStack(spacing: 8) {
                    Text("she watches my bedtime")
                        .font(.cute(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if isWorking { ProgressView().controlSize(.small) }
                }
            }
            .disabled(isWorking)
            Text(model.isAuthorized
                 ? "screen time access granted ✓"
                 : "turning this on asks for Screen Time access. it stays on your phone.")
                .font(.cute(13))
                .foregroundStyle(Theme.soft)
        }
        .cuteCard()
    }

    private var times: some View {
        VStack(spacing: 14) {
            DatePicker(selection: Binding(
                get: { model.bedtime },
                set: { model.updateBedtime($0) }
            ), displayedComponents: .hourAndMinute) {
                Text("lights off at")
                    .font(.cute(16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            DatePicker(selection: Binding(
                get: { model.wakeTime },
                set: { model.updateWakeTime($0) }
            ), displayedComponents: .hourAndMinute) {
                Text("she wakes up at")
                    .font(.cute(16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text("she comes out at lights-off, and if you keep going she's back every 15 minutes, a little grumpier each time.")
                .font(.cute(13))
                .foregroundStyle(Theme.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cuteCard()
    }

    private var apps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                pickerSelection = model.selection
                showPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("apps that keep you up")
                            .font(.cute(16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(model.selectionSummary)
                            .font(.cute(13))
                            .foregroundStyle(Theme.soft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.soft)
                }
            }
            .disabled(!model.isAuthorized)
            Toggle(isOn: Binding(
                get: { model.shieldAllApps },
                set: { model.updateShieldAllApps($0) }
            )) {
                Text("she blocks every app, not just those")
                    .font(.cute(15))
                    .foregroundStyle(Theme.ink)
            }
            if !model.isAuthorized {
                Text("turn her on first, then pick apps.")
                    .font(.cute(13))
                    .foregroundStyle(Theme.soft)
            } else if !model.hasSelection {
                Text("pick at least one app so she can tell when you're still using the phone.")
                    .font(.cute(13))
                    .foregroundStyle(Theme.blush)
            }
        }
        .cuteCard()
    }

    private var danger: some View {
        Button(role: .destructive) {
            confirmReset = true
        } label: {
            Text("reset her mood")
                .font(.cute(15))
                .foregroundStyle(Theme.blush)
                .frame(maxWidth: .infinity)
        }
        .cuteCard()
    }

    private var about: some View {
        Text("roommate uses Apple's Screen Time API. what you do on your phone never leaves it – she's the only one who knows.")
            .font(.cute(12))
            .foregroundStyle(Theme.soft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}
