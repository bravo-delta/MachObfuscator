extension UInt64 {
    func extract(from: Int, to: Int) -> UInt64 {
        let mask = UInt64(((UInt64(1)<<(UInt64(to)-UInt64(from)+UInt64(1)))-UInt64(1)) << UInt64(from))
        return (self & mask) >> from
    }
}
