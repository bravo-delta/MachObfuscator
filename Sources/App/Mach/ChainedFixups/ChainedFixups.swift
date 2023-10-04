import Foundation


public var DYLD_CHAINED_PTR_START_NONE = 0xFFFF // used in page_start[] to denote a page with no fixups
public var DYLD_CHAINED_PTR_START_MULTI  = 0x8000 // used in page_start[] to denote a page which has multiple starts
public var DYLD_CHAINED_PTR_START_LAST   = 0x8000 // used in chain_starts[] to denote last start in list for page

public var DYLD_CHAINED_PTR_64 = 2
public var DYLD_CHAINED_PTR_64_OFFSET = 6

public var DYLD_CHAINED_IMPORT: UInt32 = 1
public var DYLD_CHAINED_IMPORT_ADDEND: UInt32 = 2
public var DYLD_CHAINED_IMPORT_ADDEND64: UInt32 = 3

enum ChainedFixups {
    
    struct dyld_chained_fixups_header
    {
        var fixups_version: UInt32    // 0
        var starts_offset: UInt32     // offset of dyld_chained_starts_in_image in chain_data
        var imports_offset: UInt32    // offset of imports table in chain_data
        var symbols_offset: UInt32    // offset of symbol strings in chain_data
        var imports_count: UInt32     // number of imported symbol names
        var imports_format: UInt32    // DYLD_CHAINED_IMPORT*
        var symbols_format: UInt32    // 0 => uncompressed, 1 => zlib compressed
    }

    struct dyld_chained_starts_in_image
    {
        var seg_count: UInt32
        var seg_info_offset: [UInt32]  // each entry is offset into this struct for that segment
        // followed by pool of dyld_chain_starts_in_segment data

        init(data: Data, offset: Int) {
            var currentOffset = offset
            let count: UInt32 = data.getStruct(atOffset: currentOffset)
            currentOffset += 4
            self.seg_count = count
            self.seg_info_offset = data.getStructs(atOffset: currentOffset, count: Int(count))
        }
    }

    // This struct is embedded in dyld_chain_starts_in_image
    // and passed down to the kernel for page-in linking
    struct dyld_chained_starts_in_segment
    {
        var size: UInt32               // size of this (amount kernel needs to copy)
        var page_size: UInt16          // 0x1000 or 0x4000
        var pointer_format: UInt16     // DYLD_CHAINED_PTR_*
        var segment_offset: UInt64     // offset in memory to start of segment
        var max_valid_pointer: UInt32  // for 32-bit OS, any value beyond this is not a pointer
        var page_count: UInt16         // how many pages are in array
        var page_start: [UInt16]      // each entry is offset in each page of first element in chain
                                        // or DYLD_CHAINED_PTR_START_NONE if no fixups on page
     // uint16_t    chain_starts[1];    // some 32-bit formats may require multiple starts per page.
                                        // for those, if high bit is set in page_starts[], then it
                                        // is index into chain_starts[] which is a list of starts
                                        // the last of which has the high bit set

        init(data: Data, offset: Int) {
            var currentOffset = offset
            self.size = data.getStruct(atOffset: currentOffset)
            currentOffset += 4
            self.page_size = data.getStruct(atOffset: currentOffset)
            currentOffset += 2
            self.pointer_format = data.getStruct(atOffset: currentOffset)
            currentOffset += 2
            self.segment_offset = data.getStruct(atOffset: currentOffset)
            currentOffset += 8
            self.max_valid_pointer = data.getStruct(atOffset: currentOffset)
            currentOffset += 4
            let pageCount: UInt16 = data.getStruct(atOffset: currentOffset)
            self.page_count = pageCount
            currentOffset += 2
            self.page_start = data.getStructs(atOffset: currentOffset, count: Int(pageCount))
        }
    }

    // This struct is embedded in __TEXT,__chain_starts section in firmware
    struct dyld_chained_starts_offsets
    {
        var pointer_format: UInt32     // DYLD_CHAINED_PTR_32_FIRMWARE
        var starts_count: UInt32       // number of starts in array
        var chain_starts: [UInt32]    // array chain start offsets
    }

    struct dyld_chained_ptr_64_rebase {
        private let data: UInt64

        init(data: Data, offset: Int) {
            let uint64: UInt64 = data.getStruct(atOffset: offset)
            self.data = uint64
        }

        var target: UInt64 {
            return data.extract(from: 0, to: 35)
        }

        var high8: UInt64 {
            return data.extract(from: 36, to: 43)
        }

        var reserved: UInt64 {
            return data.extract(from: 44, to: 50)
        }

        var next: UInt64 {
            return data.extract(from: 51, to: 62)
        }

        var bind: UInt64 {
            return data.extract(from: 63, to: 63)
        }
    }

    struct dyld_chained_ptr_64_bind {
        private let data: UInt64

        init(data: Data, offset: Int) {
            let uint64: UInt64 = data.getStruct(atOffset: offset)
            self.data = uint64
        }

        var ordinal: UInt64 {
            return data.extract(from: 0, to: 23)
        }

        var addend: UInt64 {
            return data.extract(from: 24, to: 31)
        }

        var reserved: UInt64 {
            return data.extract(from: 32, to: 50)

        }
        var next: UInt64 {
            return data.extract(from: 51, to: 62)
        }

        var bind: UInt64 {
            return data.extract(from: 63, to: 63)
        }
    }

    struct dyld_chained_import {
        private let data: UInt32

        var lib_ordinal: UInt32 {
            return data.extract(from: 0, to: 7)
        }
        var weak_import: UInt32 {
            return data.extract(from: 8, to: 8)
        }
        var name_offset: UInt32 {
            return data.extract(from: 9, to: 31)
        }
    }

    struct dyld_chained_import_addend {
        var data: UInt32
        var addend: Int32

        var lib_ordinal: UInt32 {
            return data.extract(from: 0, to: 7)
        }
        var weak_import: UInt32 {
            return data.extract(from: 8, to: 8)
        }
        var name_offset: UInt32 {
            return data.extract(from: 9, to: 31)
        }
    }

    struct dyld_chained_import_addend64 {
        var data: UInt64
        var addend: UInt64

        var lib_ordinal: UInt64 {
            return data.extract(from: 0, to: 15)
        }
        var weak_import: UInt64 {
            return data.extract(from: 16, to: 16)
        }
        var reserved: UInt64 {
            return data.extract(from: 17, to: 31)
        }
        var name_offset: UInt64 {
            return data.extract(from: 32, to: 63)
        }
    }
}
