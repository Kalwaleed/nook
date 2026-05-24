import Foundation

public actor SpaceStore {
    private let defaults: UserDefaults
    private let key = "spaceNames"

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func setName(_ name: String, for uuid: String) {
        var mappings = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
        mappings[uuid] = name
        defaults.set(mappings, forKey: key)
    }

    public func deleteName(for uuid: String) {
        var mappings = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
        mappings.removeValue(forKey: uuid)
        defaults.set(mappings, forKey: key)
    }

    public func allMappings() -> [String: String] {
        (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    public func name(for uuid: String) -> String? {
        let mappings = defaults.dictionary(forKey: key) as? [String: String]
        return mappings?[uuid]
    }
}

extension SpaceStore: SpaceStoreProtocol {}
