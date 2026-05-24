public func indexedDisplayName(for uuid: String, in spaces: [(uuid: String, name: String?)]) -> String {
    guard let idx = spaces.firstIndex(where: { $0.uuid == uuid }) else {
        return "Desktop 1"
    }
    guard let name = spaces[idx].name else {
        return "Desktop \(idx + 1)"
    }
    let sameNamed = spaces.filter { $0.name == name }
    guard sameNamed.count > 1 else { return name }
    let rank = sameNamed.firstIndex(where: { $0.uuid == uuid })! + 1
    return "\(name) \(rank)"
}
