import SwiftUI
import KhanCore
import KhanIPC

struct FixNotchView: View {
    let message: PresentableMessage

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: message.iconName ?? message.source.sfSymbol)
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.headline)
                if let body = message.body, !body.isEmpty {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
            if message.clickAction != nil {
                Image(systemName: "arrow.up.forward.app")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 360, maxWidth: 480)
        .contentShape(Rectangle())
        .onTapGesture {
            if let action = message.clickAction { ClickActionRouter.execute(action) }
        }
    }
}
