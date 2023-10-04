import Foundation

struct Image {
    var url: URL

    enum Contents {
        case fat(Fat)
        case mach(Mach)
    }

    var contents: Contents
}

struct Fat {
    var data: Data

    struct Architecture {
        var offset: UInt64
        var mach: Mach
    }

    var architectures: [Architecture]
}

struct Mach {
    var data: Data

    enum MachType {
        case executable
        case other
    }

    var type: MachType

    struct Cpu: Equatable, Hashable {
        var type: Int32
        var subtype: Int32
    }

    var cpu: Cpu

    enum Platform {
        case macos
        case ios
        case watchos
        case tvos
    }

    var platform: Platform

    var rpaths: [String]
    var dylibs: [String]

    struct Section: Equatable {
        var name: String
        var range: Range<UInt64>
    }

    struct Segment: Equatable {
        var name: String
        var vmRange: Range<UInt64>
        var fileRange: Range<UInt64>
        var sections: [Section]
    }

    var segments: [Segment]

    struct Symtab: Equatable {
        var offser: UInt64
        var numberOfSymbols: UInt64
        var stringTableRange: Range<UInt64>
    }

    var symtab: Symtab?

    struct DyldInfo: Equatable {
        var bind: Range<UInt64>
        var weakBind: Range<UInt64>
        var lazyBind: Range<UInt64>
        var exportRange: Range<UInt64>
    }

    var dyldInfo: DyldInfo?

    struct ExportsTrie: Equatable {
        var cmd: Range<UInt64>
        var data: Range<UInt64>
    }

    var exportsTrie: ExportsTrie?

    struct ChainedFixups: Equatable {
        var cmd: Range<UInt64>
        var data: Range<UInt64>
    }

    var chainedFixups: ChainedFixups?
}
