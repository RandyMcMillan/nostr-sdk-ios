//
//  ContextAwareHeaderView.swift
//  NostrSDKDemo
//
//  Created by Copilot on 6/9/26.
//

import SwiftUI

struct ContextAwareHeaderView<Hero: View, Accessory: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let hero: Hero
    let accessory: Accessory

    init(title: String,
         subtitle: String? = nil,
         systemImage: String,
         @ViewBuilder hero: () -> Hero = { EmptyView() },
         @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.hero = hero()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hero

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))

                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    if let subtitle, subtitle.isEmpty == false {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 0)

                accessory
            }
        }
        .padding(.vertical, 8)
    }
}

struct HeaderMetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
