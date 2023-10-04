import Foundation
import MachO

extension Array where Element == ImportStackEntry {
    mutating func add(chainedFixupsData: Data, range: Range<Int>, weakly: Bool) {
        var stack = ImportStack()

        let fixup_base = range.lowerBound

        let header: ChainedFixups.dyld_chained_fixups_header = chainedFixupsData.getStruct(atOffset: fixup_base)

        let starts_in_image: ChainedFixups.dyld_chained_starts_in_image = ChainedFixups.dyld_chained_starts_in_image(data: chainedFixupsData, offset: fixup_base + Int(header.starts_offset))

        let offsets = starts_in_image.seg_info_offset
        for offset in offsets {
            if offset == 0 {
                continue
            }

            let startsInSegment = ChainedFixups.dyld_chained_starts_in_segment(data: chainedFixupsData, offset: fixup_base + Int(header.starts_offset) + Int(offset))

            let pageCount = Int(startsInSegment.page_count)

            for pageIndex in 0..<pageCount {
                let offsetInPage = startsInSegment.page_start[pageIndex]
                if offsetInPage == DYLD_CHAINED_PTR_START_NONE {
                    continue
                }

                if ((offsetInPage & UInt16(DYLD_CHAINED_PTR_START_MULTI)) != 0) {
                    fatalError("PTR_START_MULTI not yet supported")
                }

                var chain: UInt64 = startsInSegment.segment_offset + UInt64(startsInSegment.page_size) * UInt64(pageIndex) + UInt64(offsetInPage)
                var done = false

                while !done {
                    if startsInSegment.pointer_format == DYLD_CHAINED_PTR_64 ||
                        startsInSegment.pointer_format == DYLD_CHAINED_PTR_64_OFFSET {
                        let bind: ChainedFixups.dyld_chained_ptr_64_bind = ChainedFixups.dyld_chained_ptr_64_bind(data: chainedFixupsData, offset: Int(chain))
                        var next = bind.next
                        if bind.bind == 1 {
                            let indexOfImport = Int(bind.ordinal)

                            switch header.imports_format {
                            case DYLD_CHAINED_IMPORT:
                                let importVal: ChainedFixups.dyld_chained_import = chainedFixupsData.getStruct(atOffset: fixup_base + Int(header.imports_offset) + Int(indexOfImport * 4))
                                let symbolOffset = UInt32(fixup_base) + header.symbols_offset + importVal.name_offset
                                let symbol = chainedFixupsData.getCString(atOffset: Int(symbolOffset))
                                //print(String(format: "        0x%08x BIND     ordinal: %d   addend: %d    reserved: %d   next: %d   (%@)\n",
                                 //            chain, bind.ordinal, bind.addend, bind.reserved, bind.next, symbol))

                                var libOrdinal: Int
                                let libVal: UInt8 = UInt8(importVal.lib_ordinal)
                                if libVal > 0xF0 {
                                    libOrdinal = Int(Int8(truncatingIfNeeded: libVal))
                                } else {
                                    libOrdinal = Int(libVal)
                                }

                                let symbolRange = Range(offset: UInt64(symbolOffset), count: UInt64(symbol.count))
                                let entry = ImportStackEntry(dylibOrdinal: libOrdinal,
                                                             symbol: symbol.bytes,
                                                             symbolRange: symbolRange,
                                                             weak: weakly)
                                stack.append(entry)
                                break
                            case DYLD_CHAINED_IMPORT_ADDEND:
                                let importVal: ChainedFixups.dyld_chained_import_addend = chainedFixupsData.getStruct(atOffset: fixup_base + Int(header.imports_offset) + Int(indexOfImport * 8))
                                let symbolOffset = UInt32(fixup_base) + header.symbols_offset + importVal.name_offset
                                let symbol = chainedFixupsData.getCString(atOffset: Int(symbolOffset))
                                //print(String(format: "        0x%08x BIND     ordinal: %d   addend: %d    reserved: %d   next: %d   (%@)\n",
                                 //                   chain, bind.ordinal, bind.addend, bind.reserved, bind.next, symbol))

                                var libOrdinal: Int
                                let libVal: UInt8 = UInt8(importVal.lib_ordinal)
                                if libVal > 0xF0 {
                                    libOrdinal = Int(Int8(truncatingIfNeeded: libVal))
                                } else {
                                    libOrdinal = Int(libVal)
                                }

                                let symbolRange = Range(offset: UInt64(symbolOffset), count: UInt64(symbol.count))
                                let entry = ImportStackEntry(dylibOrdinal: libOrdinal,
                                                             symbol: symbol.bytes,
                                                             symbolRange: symbolRange,
                                                             weak: (importVal.weak_import != 0))
                                stack.append(entry)
                                break
                            case DYLD_CHAINED_IMPORT_ADDEND64:
                                let importVal: ChainedFixups.dyld_chained_import_addend64 = chainedFixupsData.getStruct(atOffset: fixup_base + Int(header.imports_offset) + Int(indexOfImport * 16))
                                let symbolOffset = UInt64(fixup_base) + UInt64(header.symbols_offset) + importVal.name_offset
                                let symbol = chainedFixupsData.getCString(atOffset: Int(symbolOffset))
                                //print(String(format: "        0x%08x BIND     ordinal: %d   addend: %d    reserved: %d   next: %d   (%@)\n",
                                //                    chain, bind.ordinal, bind.addend, bind.reserved, bind.next, symbol))

                                var libOrdinal: Int
                                let libVal: UInt16 = UInt16(importVal.lib_ordinal)
                                if libVal > 0xFFF0 {
                                    libOrdinal = Int(Int16(truncatingIfNeeded: libVal))
                                } else {
                                    libOrdinal = Int(libVal)
                                }

                                let symbolRange = Range(offset: UInt64(symbolOffset), count: UInt64(symbol.count))
                                let entry = ImportStackEntry(dylibOrdinal: libOrdinal,
                                                             symbol: symbol.bytes,
                                                             symbolRange: symbolRange,
                                                             weak: (importVal.weak_import != 0))
                                stack.append(entry)
                                break
                            default:
                                fatalError("Unsupported chained import format")
                                break
                            }


                        } else {
                            let rebase: ChainedFixups.dyld_chained_ptr_64_rebase = ChainedFixups.dyld_chained_ptr_64_rebase(data: chainedFixupsData, offset: Int(chain))
                            //print(String(format: "        %#010x REBASE   target: %#010llx   high8: %d   next: %d\n",
                            //             chain, rebase.target, rebase.high8, rebase.next))
                            next = rebase.next
                        }

                        if next == 0 {
                            done = true
                        } else {
                            chain += next * 4
                        }
                    } else {
                        fatalError("unsupported pointer format")
                        break
                    }
                }
            }
        }
        append(contentsOf: stack)
    }
}

extension Array where Element == ImportStackEntry {
    mutating func add(opcodesData: Data, range: Range<Int>, weakly: Bool) {
        let parsedStack = opcodesData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> ImportStack in
            var stack = ImportStack()
            var dylibOrdinal: Int = 0
            var symbolBytes: [UInt8]?
            var symbolStart: Int?
            var cursorPtr = bytes.baseAddress!.advanced(by: range.lowerBound)
            let end = bytes.baseAddress!.advanced(by: range.upperBound)
            while cursorPtr < end {
                let opcode = Int32(cursorPtr.load(as: UInt8.self))
                cursorPtr = cursorPtr.advanced(by: 1)
                switch opcode & BIND_OPCODE_MASK {
                case BIND_OPCODE_DONE:
                    dylibOrdinal = 0
                    symbolBytes = nil
                    symbolStart = nil
                case BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
                    dylibOrdinal = Int(opcode & BIND_IMMEDIATE_MASK)
                case BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                    dylibOrdinal = Int(cursorPtr.readUleb128())
                case BIND_OPCODE_SET_DYLIB_SPECIAL_IMM:
                    fatalError("Unsupported opcode BIND_OPCODE_SET_DYLIB_SPECIAL_IMM")
                case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM:
                    symbolStart = bytes.baseAddress!.distance(to: cursorPtr)
                    symbolBytes = cursorPtr.readStringBytes()
                case BIND_OPCODE_SET_TYPE_IMM: break
                case BIND_OPCODE_SET_ADDEND_SLEB:
                    _ = cursorPtr.readSleb128()
                case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB:
                    _ = cursorPtr.readUleb128()
                case BIND_OPCODE_ADD_ADDR_ULEB:
                    _ = cursorPtr.readUleb128()
                case BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB:
                    _ = cursorPtr.readUleb128()
                    fallthrough
                case BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB:
                    _ = cursorPtr.readUleb128()
                    fallthrough
                case BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED: fallthrough
                case BIND_OPCODE_DO_BIND:
                    guard
                        let symbolBytes = symbolBytes,
                        let symbolStart = symbolStart
                    else {
                        fatalError("BIND_OPCODE_DO_BIND record has no symbol")
                    }
                    let symbolRange = Range(offset: UInt64(symbolStart), count: UInt64(symbolBytes.count))
                    let entry = ImportStackEntry(dylibOrdinal: dylibOrdinal,
                                                 symbol: symbolBytes,
                                                 symbolRange: symbolRange,
                                                 weak: weakly)
                    stack.append(entry)
                default:
                    fatalError("Unsupported opcode \(opcode)")
                }
            }
            return stack
        }
        append(contentsOf: parsedStack)
    }

    mutating func resolveMissingDylibOrdinals() {
        let indiciesWithoutDylibOrdinal = enumerated().filter { _, entry in entry.dylibOrdinal == 0 }.map { offset, _ in offset }
        guard !indiciesWithoutDylibOrdinal.isEmpty else {
            return
        }
        let dylibOrdinalsPerSymbol: [String: [Int]] = Dictionary(grouping: self) { $0.symbolString }
            .mapValues { $0.map { $0.dylibOrdinal }.filter { $0 != 0 } }
        for index in indiciesWithoutDylibOrdinal {
            let symbolString = self[index].symbolString
            if let matchedOrdinal = dylibOrdinalsPerSymbol[symbolString]?.first {
                self[index].dylibOrdinal = matchedOrdinal
            } else if !self[index].weak {
                fatalError("Could not resolve '\(symbolString)' binding info")
            }
        }
    }
}
