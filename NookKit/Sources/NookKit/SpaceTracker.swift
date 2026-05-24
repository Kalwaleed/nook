import AppKit
import Combine
import CoreGraphics

private typealias CGSConnectionID = UInt32
private typealias CGSSpaceID = UInt64

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray

struct SpaceInfo: Equatable {
    let uuid: String
    let displayID: UInt32
    let isActive: Bool
}

protocol SpaceTrackerProtocol: AnyObject {
    func spaces(for displayID: UInt32) -> [SpaceInfo]
    func activeSpace(for displayID: UInt32) -> SpaceInfo?
    var spaceChanges: AnyPublisher<[SpaceInfo], Never> { get }
}

final class CGSSpaceTracker: SpaceTrackerProtocol {
    private let subject = PassthroughSubject<[SpaceInfo], Never>()
    private var observer: NSObjectProtocol?

    init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.subject.send(self?.allSpaces() ?? [])
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func spaces(for displayID: UInt32) -> [SpaceInfo] {
        allSpaces().filter { $0.displayID == displayID }
    }

    func activeSpace(for displayID: UInt32) -> SpaceInfo? {
        spaces(for: displayID).first(where: { $0.isActive })
    }

    var spaceChanges: AnyPublisher<[SpaceInfo], Never> {
        subject.eraseToAnyPublisher()
    }

    private func allSpaces() -> [SpaceInfo] {
        let cid = CGSMainConnectionID()
        guard let displays = CGSCopyManagedDisplaySpaces(cid) as? [[String: Any]] else { return [] }
        var result: [SpaceInfo] = []
        for (index, display) in displays.enumerated() {
            let displayID = UInt32(index)
            let activeUUID = (display["Current Space"] as? [String: Any])?["uuid"] as? String
            let spaceList = display["Spaces"] as? [[String: Any]] ?? []
            for space in spaceList {
                guard let uuid = space["uuid"] as? String else { continue }
                result.append(SpaceInfo(uuid: uuid, displayID: displayID, isActive: uuid == activeUUID))
            }
        }
        return result
    }
}

final class MockSpaceTracker: SpaceTrackerProtocol {
    var stubbedSpaces: [UInt32: [SpaceInfo]] = [:]
    private let subject = PassthroughSubject<[SpaceInfo], Never>()

    func spaces(for displayID: UInt32) -> [SpaceInfo] {
        stubbedSpaces[displayID] ?? []
    }

    func activeSpace(for displayID: UInt32) -> SpaceInfo? {
        stubbedSpaces[displayID]?.first(where: { $0.isActive })
    }

    func simulateSpaceChange(spaces: [SpaceInfo]) {
        subject.send(spaces)
    }

    var spaceChanges: AnyPublisher<[SpaceInfo], Never> {
        subject.eraseToAnyPublisher()
    }
}
