//
//  LimitsView.swift
//  NoFeed
//
//  Daily limits: "these apps, this long a day". Flat rows in the Quiet style —
//  name, allowance, and a switch — with the editor one tap away.
//

import SwiftUI

struct LimitsView: View {
    @Environment(LimitStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    @State private var editing: AppLimit?

    private var tone: Color { ZTheme.tone(forHex: profiles.activeProfile?.accentHex) }

    var body: some View {
        NavigationStack {
            ZStack {
                NoFeedBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Daily limits")
                                .font(ZTheme.Font.display(24, weight: .semibold))
                                .foregroundStyle(ZTheme.Palette.textPrimary)
                            Spacer()
                            Button("Done") { dismiss() }
                                .font(ZTheme.Font.body(15))
                                .foregroundStyle(ZTheme.Palette.text(0.55))
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("limits-done")
                        }
                        .padding(.bottom, 8)

                        Text("Use these apps as much as you like each day, up to the limit. Then they lock until tomorrow.")
                            .font(ZTheme.Font.body(14))
                            .foregroundStyle(ZTheme.Palette.text(0.55))
                            .padding(.bottom, 24)

                        ForEach(store.limits) { limit in
                            row(limit)
                            QuietHairline(color: ZTheme.Palette.glassFill)
                        }

                        Button {
                            Haptics.light()
                            editing = AppLimit()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("New limit")
                                    .font(ZTheme.Font.display(15, weight: .semibold))
                            }
                            .foregroundStyle(tone.readable)
                            .frame(minHeight: 44)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("limits-new")
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { limit in
                LimitEditView(limit: limit,
                              isNew: !store.limits.contains { $0.id == limit.id })
            }
        }
    }

    private func row(_ limit: AppLimit) -> some View {
        HStack(spacing: 14) {
            Button {
                Haptics.light()
                editing = limit
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: limit.displayName)
                        .font(ZTheme.Font.body(15))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Text(verbatim: subtitle(limit))
                        .font(ZTheme.Font.body(12.5))
                        .foregroundStyle(store.isReached(limit.id) ? ZTheme.Palette.alert : ZTheme.Palette.text(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("limit-row-\(limit.displayName)")

            Toggle("", isOn: Binding(get: { limit.isEnabled },
                                     set: { store.setEnabled($0, for: limit.id) }))
                .labelsHidden()
                .tint(tone)
                .accessibilityLabel(Text(verbatim: limit.displayName))
        }
        .padding(.vertical, 14)
    }

    private func subtitle(_ limit: AppLimit) -> String {
        let allowance = String(localized: "\(limit.minutes) min a day")
        if store.isReached(limit.id) { return String(localized: "Used up today · \(allowance)") }
        if limit.itemCount == 0 { return String(localized: "No apps chosen") }
        return "\(String(localized: "\(limit.itemCount) apps")) · \(allowance)"
    }
}

struct LimitEditView: View {
    @Environment(LimitStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AppLimit
    @State private var showPicker = false
    @State private var confirmDelete = false
    let isNew: Bool

    init(limit: AppLimit, isNew: Bool) {
        _draft = State(initialValue: limit)
        self.isNew = isNew
    }

    private var tone: Color { ZTheme.tone(forHex: profiles.activeProfile?.accentHex) }
    private var isReady: Bool { draft.itemCount > 0 }

    var body: some View {
        NavigationStack {
            QuietEditorScaffold(
                title: isNew ? "New limit" : "Edit limit",
                cancelTitle: "Cancel",
                status: isReady ? "Ready when you are" : "Choose the apps to limit",
                statusIsAlert: false,
                ctaTitle: isNew ? "Add limit" : "Save changes",
                ctaIdentifier: "limit-save",
                isReady: isReady,
                tone: tone,
                onCancel: { dismiss() },
                onSubmit: {
                    store.save(draft)
                    dismiss()
                }
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    QuietFieldLabel(text: "Name")
                    QuietTextField(placeholder: "Daily limit", text: $draft.name)
                        .submitLabel(.done)
                        .accessibilityIdentifier("limit-name")

                    QuietFieldLabel(text: "Apps", topPadding: QuietMetrics.sectionGap)
                    QuietDisclosureRow(title: "Limited apps",
                                       value: draft.itemCount == 0 ? "Choose" : "\(draft.itemCount) apps") {
                        showPicker = true
                    }
                    .accessibilityIdentifier("limit-choose-apps")

                    QuietFieldLabel(text: "Each day", topPadding: QuietMetrics.sectionGap)
                    QuietStepperRow(
                        value: "\(draft.minutes) min",
                        canDecrement: draft.minutes > AppLimitStore.range.lowerBound,
                        canIncrement: draft.minutes < AppLimitStore.range.upperBound,
                        onDecrement: { draft.minutes = max(AppLimitStore.range.lowerBound, draft.minutes - AppLimitStore.step) },
                        onIncrement: { draft.minutes = min(AppLimitStore.range.upperBound, draft.minutes + AppLimitStore.step) })
                    QuietHelper(text: draft.minutes > AppLimitStore.warningMinutes * 2
                                ? "A notification arrives five minutes before the limit. At the limit, these apps lock until midnight."
                                : "At the limit, these apps lock until midnight.")
                        .padding(.top, 10)

                    if !isNew {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Delete limit")
                                .font(ZTheme.Font.body(15))
                                .foregroundStyle(ZTheme.Palette.alert)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, QuietMetrics.sectionGap)
                        .accessibilityIdentifier("limit-delete")
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .familyActivityPicker(isPresented: $showPicker, selection: Binding(
                get: { draft.selection },
                set: { draft.selection = $0 }))
            .confirmationDialog("Delete this limit?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(draft.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
