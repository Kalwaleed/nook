import Foundation

actor SpaceStore {
    private let defaults: UserDefaults
    private let key = "spaceNames"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func setName(_ name: String, for uuid: String) {
        var mappings = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
        mappings[uuid] = name
        defaults.set(mappings, forKey: key)
    }

    func deleteName(for uuid: String) {
        var mappings = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
        mappings.removeValue(forKey: uuid)
        defaults.set(mappings, forKey: key)
    }

    func allMappings() -> [String: String] {
        (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    func name(for uuid: String) -> String? {
        let mappings = defaults.dictionary(forKey: key) as? [String: String]
        return mappings?[uuid]
    }
}
