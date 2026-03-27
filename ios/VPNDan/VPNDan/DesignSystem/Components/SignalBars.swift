import SwiftUI

struct SignalBars: View {
    let quality: LatencyQuality?

    private let barCount = 4
    private let barWidth: CGFloat
    private let barSpacing: CGFloat
    private let maxHeight: CGFloat
    private let minHeight: CGFloat

    @State private var appeared = false

    /// - Parameters:
    ///   - quality: The latency quality level. `nil` means no data (0 bars).
    ///   - size: Controls the overall scale. `.regular` for the home gauge, `.compact` for server rows.
    init(quality: LatencyQuality?, size: Size = .regular) {
        self.quality = quality
        switch size {
        case .regular:
            barWidth = 6
            barSpacing = 3
            maxHeight = 28
            minHeight = 6
        case .compact:
            barWidth = 4
            barSpacing = 2
            maxHeight = 16
            minHeight = 4
        }
    }

    private var activeBars: Int {
        guard let quality else { return 0 }
        switch quality {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        }
    }

    private var activeColor: Color {
        quality?.color ?? Color.vpnTextTertiary
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let isActive = appeared && index < activeBars
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? activeColor : Color.vpnBorder.opacity(0.3))
                    .frame(width: barWidth, height: barHeight(for: index))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.08),
                        value: appeared
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.08),
                        value: quality
                    )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                appeared = true
            }
        }
        .onChange(of: quality) {
            appeared = false
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let step = (maxHeight - minHeight) / CGFloat(barCount - 1)
        return minHeight + step * CGFloat(index)
    }

    enum Size {
        case regular
        case compact
    }
}
