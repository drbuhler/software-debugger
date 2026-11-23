import Foundation

/// Picks a spot on the desktop for a burrow, away from the corner hamster and from other holes.
public enum BurrowPlanner {
    public static func place(existing: [SavedBurrow], screenCount: Int, random: inout SplitMix64) -> SavedBurrow? {
        let screens = max(1, screenCount)
        for _ in 0..<24 {
            let screenIndex = screens == 1 ? 0 : Int(random.unit() * Double(screens))
            let x = random.double(in: 0.06...0.86)
            let y = random.double(in: 0.05...0.58)
            let crowded = existing.contains { other in
                guard other.screenIndex == screenIndex else { return false }
                let dx = other.x - x
                let dy = other.y - y
                return (dx * dx + dy * dy) < 0.02
            }
            if crowded { continue }
            let pellets = 1 + Int(random.double(in: 0...2.999))
            return SavedBurrow(
                screenIndex: min(screenIndex, screens - 1),
                x: x,
                y: y,
                pellets: min(3, max(1, pellets))
            )
        }
        return nil
    }
}
