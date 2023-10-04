import Foundation

extension StringProtocol {
    var data: Data { .init(utf8) }
    var bytes: [UInt8] { .init(utf8) }
}
