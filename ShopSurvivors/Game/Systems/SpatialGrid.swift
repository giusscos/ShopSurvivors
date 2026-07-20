import CoreGraphics
import Foundation

/// Uniform grid for nearby-neighbor queries (clerks, shelves).
struct SpatialGrid {
    let cellSize: CGFloat
    private(set) var buckets: [Int: [Int]] = [:]

    init(cellSize: CGFloat) {
        self.cellSize = max(1, cellSize)
    }

    mutating func clear() {
        buckets.removeAll(keepingCapacity: true)
    }

    mutating func rebuild(count: Int, position: (Int) -> CGPoint) {
        // Wipe values in place — avoids rehash churn from removeAll every frame.
        for key in buckets.keys {
            buckets[key]?.removeAll(keepingCapacity: true)
        }
        guard count > 0 else { return }
        for i in 0..<count {
            let p = position(i)
            let key = cellKey(p.x, p.y)
            buckets[key, default: []].append(i)
        }
    }

    mutating func insert(_ index: Int, at point: CGPoint) {
        let key = cellKey(point.x, point.y)
        buckets[key, default: []].append(index)
    }

    func forEachNearby(to point: CGPoint, cellsRadius: Int = 1, _ body: (Int) -> Void) {
        let cx = cellCoord(point.x)
        let cy = cellCoord(point.y)
        for gy in (cy - cellsRadius)...(cy + cellsRadius) {
            for gx in (cx - cellsRadius)...(cx + cellsRadius) {
                guard let list = buckets[pack(gx, gy)], !list.isEmpty else { continue }
                for index in list {
                    body(index)
                }
            }
        }
    }

    private func cellCoord(_ v: CGFloat) -> Int {
        Int(floor(v / cellSize))
    }

    private func cellKey(_ x: CGFloat, _ y: CGFloat) -> Int {
        pack(cellCoord(x), cellCoord(y))
    }

    private func pack(_ x: Int, _ y: Int) -> Int {
        // Cantor-ish packing with offset so negatives work.
        let xx = x &+ 4096
        let yy = y &+ 4096
        return (xx &<< 16) &+ yy
    }
}
