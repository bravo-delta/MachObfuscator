import Foundation

extension Mach {
    var exportedTrie: Trie? {
        if let exportsTrie = exportsTrie,
           !exportsTrie.data.isEmpty {
            return Trie(data: data, rootNodeOffset: Int(exportsTrie.data.lowerBound))
              } else {
            guard let dyldInfo = dyldInfo,
                  !dyldInfo.exportRange.isEmpty
            else { return nil }
            return Trie(data: data, rootNodeOffset: Int(dyldInfo.exportRange.lowerBound))
        }
    }
}
