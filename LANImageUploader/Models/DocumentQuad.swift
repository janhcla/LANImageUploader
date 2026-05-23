import Foundation

struct DocumentQuad: Codable, Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint

    var isEmpty: Bool {
        return topLeft == .zero && topRight == .zero && bottomLeft == .zero && bottomRight == .zero
    }

    static var defaultQuad: DocumentQuad {
        return DocumentQuad(
            topLeft: CGPoint(x: 0.1, y: 0.9), // Vision's origin is bottom-left, so (0,1) is top-left
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomLeft: CGPoint(x: 0.1, y: 0.1),
            bottomRight: CGPoint(x: 0.9, y: 0.1)
        )
    }
}
