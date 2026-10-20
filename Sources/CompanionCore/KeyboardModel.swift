import Foundation

public struct PhysicalKey: Equatable {
    public let code: UInt16
    public let label: String
    public let column: Double
    public let row: Double
    public let width: Double
    public let height: Double
    public var rightHand: Bool { column + width / 2 >= 7.5 }
}

/// Mac virtual key codes identify physical keys, never characters from a typed event.
public enum MacKeyboard {
    public static let modifiers: Set<UInt16> = [54,55,56,57,58,59,60,61,62,63]
    public static func keys() -> [PhysicalKey] {
        var result: [PhysicalKey] = []
        func row(_ y: Double, _ entries: [(UInt16, String, Double)], height: Double = 1) {
            var x = 0.0
            for (code, label, width) in entries {
                result.append(PhysicalKey(code: code, label: label, column: x, row: y, width: width, height: height)); x += width
            }
        }
        row(0, [(53,"esc",1.5),(122,"F1",1),(120,"F2",1),(99,"F3",1),(118,"F4",1),(96,"F5",1),(97,"F6",1),(98,"F7",1),(100,"F8",1),(101,"F9",1),(109,"F10",1),(103,"F11",1),(111,"F12",1)], height: 0.65)
        row(0.85, [(50,"`",1),(18,"1",1),(19,"2",1),(20,"3",1),(21,"4",1),(23,"5",1),(22,"6",1),(26,"7",1),(28,"8",1),(25,"9",1),(29,"0",1),(27,"−",1),(24,"=",1),(51,"⌫",2)])
            row(1.85, [(48,"⇥",1.5),(12,"Q",1),(13,"W",1),(14,"E",1),(15,"R",1),(17,"T",1),(16,"Y",1),(32,"U",1),(34,"I",1),(31,"O",1),(35,"P",1),(33,"[",1),(30,"]",1),(42,"\\",1.5)])
            row(2.85, [(57,"⇪",1.75),(0,"A",1),(1,"S",1),(2,"D",1),(3,"F",1),(5,"G",1),(4,"H",1),(38,"J",1),(40,"K",1),(37,"L",1),(41,";",1),(39,"'",1),(36,"↵",2.25)])
            row(3.85, [(56,"⇧",2.25),(6,"Z",1),(7,"X",1),(8,"C",1),(9,"V",1),(11,"B",1),(45,"N",1),(46,"M",1),(43,",",1),(47,".",1),(44,"/",1),(60,"⇧",2.75)])
        row(4.85, [(63,"fn",1),(59,"⌃",1),(58,"⌥",1),(55,"⌘",1.25),(49,"space",5.5),(54,"⌘",1.25),(61,"⌥",1),(123,"◀",1)])
        result.append(PhysicalKey(code: 126, label: "▲", column: 13, row: 4.85, width: 1, height: 0.5))
        result.append(PhysicalKey(code: 125, label: "▼", column: 13, row: 5.35, width: 1, height: 0.5))
        result.append(PhysicalKey(code: 124, label: "▶", column: 14, row: 4.85, width: 1, height: 1))
        return result
    }
}

/// Only currently held keys, bounded to the layout. No input history or timestamps.
public struct HeldKeyboard {
    public private(set) var order: [UInt16] = []
    public var held: Set<UInt16> { Set(order) }
    public init() {}
    public mutating func update(code: UInt16, down: Bool, supported: Set<UInt16>) {
        guard supported.contains(code) else { return }
        if down {
            if !order.contains(code) { order.append(code) }
        } else { order.removeAll { $0 == code } }
    }
    public mutating func clear() { order.removeAll(keepingCapacity: false) }
}
