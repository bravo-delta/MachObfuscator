extension UInt32 {
    func extract(from: Int, to: Int) -> UInt32 {
        let mask = UInt32(((1<<(to-from+1))-1) << from)
        return (self & mask) >> from
    }
}
