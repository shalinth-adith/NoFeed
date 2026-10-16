//
//  ReflectionChips.swift
//  NoFeed
//
//  The three-word answer to "How did it feel?" — used on the completion
//  summary and on the Insights card that asks about sessions never answered.
//  One row of hairline pills; the chosen one fills with the tone.
//

import SwiftUI

struct ReflectionChips: View {
    @Binding var selection: SessionReflection
    var tone: Color = ZTheme.Palette.tone
    /// Prefix for the accessibility identifiers: "summary" → "summary-reflection-focused".
    var idPrefix: String = "summary"

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SessionReflection.choices, id: \.self) { choice in
                chip(choice)
            }
        }
        .animation(ZTheme.Motion.smooth, value: selection)
    }

    private func chip(_ choice: SessionReflection) -> some View {
        let selected = selection == choice
        return Button {
            Haptics.light()
            selection = choice
        } label: {
            HStack(spacing: 6) {
                Image(systemName: choice.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(choice.title)
                    .font(ZTheme.Font.body(13, weight: .medium))
            }
            .foregroundStyle(selected ? Color(hex: "0A0B0E") : ZTheme.Palette.text(0.70))
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(
                Capsule().fill(selected ? tone : .clear)
            )
            .overlay(
                Capsule().strokeBorder(selected ? .clear : ZTheme.Palette.glassStroke, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(idPrefix)-reflection-\(String(describing: choice))")
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
