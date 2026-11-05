import Darwin

/// Finds processes by executable name, without needing AppKit.
public enum RunningProcesses {
    public static func identifiers(named name: String) -> [pid_t] {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return [] }

        var identifiers = [pid_t](repeating: 0, count: Int(capacity))
        let bytes = Int32(identifiers.count * MemoryLayout<pid_t>.size)
        let count = proc_listallpids(&identifiers, bytes)
        guard count > 0 else { return [] }

        return identifiers.prefix(Int(count)).filter { processName(of: $0) == name }
    }

    private static func processName(of identifier: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(identifier, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }
}
