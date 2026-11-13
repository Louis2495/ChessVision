import SwiftUI

struct ReviewMoveRow: View {
    let assessment: MoveAssessment
    var body: some View {
        HStack(spacing: 8) {
            if assessment.playedTopMove { Image(systemName: "star.fill").foregroundStyle(.yellow) }
            else { Image(systemName: assessment.quality.symbol).foregroundStyle(assessment.quality.color) }
            Text(assessment.san).fontWeight(.semibold).monospaced()
            Text(assessment.quality.title).font(.caption).foregroundStyle(assessment.quality.color)
            Spacer(minLength: 4)
            if !assessment.playedTopMove, let best = assessment.bestSAN {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("Top: " + best).font(.subheadline.weight(.semibold)).monospaced()
                }
            }
        }.accessibilityElement(children: .combine)
    }
}
