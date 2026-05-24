public protocol SpaceStoreProtocol: AnyObject {
    func setName(_ name: String, for uuid: String) async
    func name(for uuid: String) async -> String?
    func deleteName(for uuid: String) async
}
