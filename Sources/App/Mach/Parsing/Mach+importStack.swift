import Foundation

extension Mach {
    var importStack: ImportStack {
        if let chainedFixups = chainedFixups {
            var importStack = ImportStack()
            if !chainedFixups.data.isEmpty {
                importStack.add(chainedFixupsData: data, range: chainedFixups.data.intRange, weakly: false)
            }
            importStack.resolveMissingDylibOrdinals()
            return importStack
        } else {
            guard let dyldInfo = dyldInfo else {
                return []
            }
            var importStack = ImportStack()
            if !dyldInfo.bind.isEmpty {
                importStack.add(opcodesData: data, range: dyldInfo.bind.intRange, weakly: false)
            }
            if !dyldInfo.weakBind.isEmpty {
                importStack.add(opcodesData: data, range: dyldInfo.weakBind.intRange, weakly: true)
            }
            if !dyldInfo.lazyBind.isEmpty {
                importStack.add(opcodesData: data, range: dyldInfo.lazyBind.intRange, weakly: false)
            }
            importStack.resolveMissingDylibOrdinals()
            return importStack
        }
    }
}
