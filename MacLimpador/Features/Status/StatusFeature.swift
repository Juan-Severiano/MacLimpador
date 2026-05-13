import Foundation
import IOKit.ps
import Darwin
import Observation

actor StatusService {
    static let shared = StatusService()

    // Previous samples for delta-based metrics
    private var previousCPUSample: host_cpu_load_info?
    private var previousNetworkBytes: (rx: UInt64, tx: UInt64, time: Date)?
    private var previousDiskBytes: (read: Int64, write: Int64, time: Date)?
    private var processHighCPUStart: [Int: Date] = [:]

    // GPU caching
    private var cachedGPUName: String?
    private var lastGPUInfoAt: Date?
    private var cachedGPUUsage: Double = -1
    private var lastGPUUsageAt: Date?

    // Hardware info (static, cached forever)
    private var cachedHardwareSummary: String?

    private init() {}

    func collect() async -> StatusSnapshot {
        let now = Date()
        let hostName = Host.current().localizedName ?? "Mac"
        let cpuUsage = collectCPUUsagePercent()
        let memory = collectMemoryUsage()
        let disk = collectDiskUsage()
        let battery = collectBatteryInfo()
        let uptimeSecs = collectUptime()

        async let networkTask = collectNetworkRates(now: now)
        async let alertsTask = collectProcessAlerts(now: now)
        async let topProcessesTask = collectTopProcesses()
        async let gpuTask = collectGPU(now: now)
        async let loadAvgTask = collectLoadAvg()
        async let diskIOTask = collectDiskIO(now: now)
        async let batteryDetailTask = collectBatteryDetail()
        async let memPressureTask = collectMemoryPressure()
        async let hardwareTask = collectHardwareSummary()

        let network = await networkTask
        let alerts = await alertsTask
        let topProcesses = await topProcessesTask
        let gpu = await gpuTask
        let loadAvg = await loadAvgTask
        let diskIO = await diskIOTask
        let batteryDetail = await batteryDetailTask
        let memPressure = await memPressureTask
        let hardware = await hardwareTask

        let (healthScore, healthMessage) = calculateHealthScore(
            cpuUsage: cpuUsage,
            memoryUsed: memory.used,
            memoryTotal: memory.total,
            memoryPressure: memPressure,
            disk: disk,
            batteryHealth: batteryDetail.health,
            thermalTemp: nil,
            diskReadMBps: diskIO.read,
            diskWriteMBps: diskIO.write,
            uptimeSecs: uptimeSecs
        )

        return StatusSnapshot(
            collectedAt: now,
            hostName: hostName,
            hardwareSummary: hardware,
            healthScore: healthScore,
            healthMessage: healthMessage,
            cpuUsagePercent: cpuUsage,
            cpuLoadAvg1: loadAvg.one,
            cpuLoadAvg5: loadAvg.five,
            cpuLoadAvg15: loadAvg.fifteen,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            memoryPressureLevel: memPressure,
            disk: disk,
            diskReadMBps: diskIO.read,
            diskWriteMBps: diskIO.write,
            gpuUsagePercent: gpu.usage,
            gpuName: gpu.name,
            batteryPercent: battery.percent,
            batteryCharging: battery.isCharging,
            batteryHealth: batteryDetail.health,
            batteryCycles: batteryDetail.cycles,
            thermalCPUTemp: nil,
            uptimeSecs: uptimeSecs,
            network: network,
            processAlerts: alerts,
            topProcesses: topProcesses
        )
    }

    // MARK: - CPU

    private func collectCPUUsagePercent() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        if let previous = previousCPUSample {
            let userDiff = Double(cpuInfo.cpu_ticks.0 - previous.cpu_ticks.0)
            let systemDiff = Double(cpuInfo.cpu_ticks.1 - previous.cpu_ticks.1)
            let idleDiff = Double(cpuInfo.cpu_ticks.2 - previous.cpu_ticks.2)
            let niceDiff = Double(cpuInfo.cpu_ticks.3 - previous.cpu_ticks.3)

            let total = userDiff + systemDiff + idleDiff + niceDiff
            previousCPUSample = cpuInfo

            guard total > 0 else { return 0 }
            let used = userDiff + systemDiff + niceDiff
            return (used / total) * 100
        } else {
            previousCPUSample = cpuInfo
            return 0
        }
    }

    private func collectLoadAvg() async -> (one: Double, five: Double, fifteen: Double) {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/usr/sbin/sysctl", arguments: ["-n", "vm.loadavg"], timeout: 2
        ), result.success else { return (0, 0, 0) }

        // Format: "{ 4.60 3.82 3.64 }"
        let cleaned = result.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
        let parts = cleaned.split(whereSeparator: { $0 == " " || $0 == "\t" }).compactMap { Double($0) }
        guard parts.count >= 3 else { return (0, 0, 0) }
        return (parts[0], parts[1], parts[2])
    }

    // MARK: - Memory

    private func collectMemoryUsage() -> (used: Int64, total: Int64) {
        var totalBytes: UInt64 = 0
        var totalSize = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &totalBytes, &totalSize, nil, 0) != 0 {
            totalBytes = 0
        }

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (used: 0, total: Int64(totalBytes))
        }

        let pageSize = vm_kernel_page_size
        let free = UInt64(vmStats.free_count) * UInt64(pageSize)
        let total = totalBytes
        let used = total > free ? total - free : 0

        return (used: Int64(used), total: Int64(total))
    }

    private func collectMemoryPressure() async -> String {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/usr/bin/memory_pressure", arguments: [], timeout: 3
        ), result.success else { return "normal" }
        let output = result.stdout.lowercased()
        if output.contains("critical") { return "critical" }
        if output.contains("warn") { return "warn" }
        return "normal"
    }

    // MARK: - Disk

    private func collectDiskUsage() -> StatusDiskSnapshot {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            let total = attrs[.systemSize] as? Int64 ?? 0
            let used = max(0, total - free)
            return StatusDiskSnapshot(usedBytes: used, totalBytes: total, freeBytes: free)
        } catch {
            return StatusDiskSnapshot(usedBytes: 0, totalBytes: 0, freeBytes: 0)
        }
    }

    private func collectDiskIO(now: Date) async -> (read: Double, write: Double) {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/usr/sbin/ioreg",
            arguments: ["-r", "-c", "IOBlockStorageDriver", "-k", "Statistics"],
            timeout: 3
        ), result.success else { return (0, 0) }

        var totalRead: Int64 = 0
        var totalWrite: Int64 = 0

        for line in result.stdout.split(separator: "\n") {
            let str = String(line)
            if str.contains("\"Bytes (Read)\""), let val = parseIORegInt64(str) {
                totalRead += val
            } else if str.contains("\"Bytes (Write)\""), let val = parseIORegInt64(str) {
                totalWrite += val
            }
        }

        defer { previousDiskBytes = (read: totalRead, write: totalWrite, time: now) }

        guard let prev = previousDiskBytes else { return (0, 0) }
        let elapsed = now.timeIntervalSince(prev.time)
        guard elapsed > 0 else { return (0, 0) }

        let readRate = Double(max(0, totalRead - prev.read)) / elapsed / 1_000_000
        let writeRate = Double(max(0, totalWrite - prev.write)) / elapsed / 1_000_000
        return (readRate, writeRate)
    }

    private nonisolated func parseIORegInt64(_ line: String) -> Int64? {
        guard let eq = line.range(of: "= ") else { return nil }
        let valStr = String(line[eq.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Int64(valStr)
    }

    // MARK: - Battery

    private func collectBatteryInfo() -> (percent: Double?, isCharging: Bool?) {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as Array

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source).takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let percent = description[kIOPSCurrentCapacityKey] as? Double
            let isCharging = description[kIOPSIsChargingKey] as? Bool
            return (percent, isCharging)
        }
        return (nil, nil)
    }

    private func collectBatteryDetail() async -> (health: String?, cycles: Int?) {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/usr/sbin/ioreg", arguments: ["-r", "-c", "AppleSmartBattery"], timeout: 3
        ), result.success else { return (nil, nil) }

        var cycles: Int? = nil
        for line in result.stdout.split(separator: "\n") {
            let str = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if str.hasPrefix("\"CycleCount\"") || str.contains("\"CycleCount\" =") {
                if let eq = str.range(of: "= ") {
                    let valStr = String(str[eq.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    cycles = Int(valStr)
                }
            }
        }

        let health: String?
        if let c = cycles {
            if c > 900 { health = "Service Soon" }
            else if c > 500 { health = "Fair" }
            else { health = "Healthy" }
        } else {
            health = nil
        }
        return (health, cycles)
    }

    // MARK: - GPU

    private func collectGPU(now: Date) async -> (name: String?, usage: Double?) {
        // Cache GPU name for 10 minutes
        if cachedGPUName == nil || lastGPUInfoAt == nil || now.timeIntervalSince(lastGPUInfoAt!) >= 600 {
            if let result = try? await SystemCommandExecutor.shared.run(
                "/usr/sbin/system_profiler", arguments: ["-json", "SPDisplaysDataType"], timeout: 5
            ), result.success, let data = result.stdout.data(using: .utf8) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let displays = json["SPDisplaysDataType"] as? [[String: Any]],
                   let first = displays.first,
                   let name = first["_name"] as? String, !name.isEmpty {
                    cachedGPUName = name
                    lastGPUInfoAt = now
                }
            }
        }

        // GPU usage via powermetrics (may require sudo — graceful fail)
        var usage: Double? = nil
        if lastGPUUsageAt == nil || now.timeIntervalSince(lastGPUUsageAt!) >= 5 {
            if let result = try? await SystemCommandExecutor.shared.run(
                "/usr/bin/powermetrics",
                arguments: ["--samplers", "gpu_power", "-i", "500", "-n", "1"],
                timeout: 3
            ), result.success {
                for line in result.stdout.split(separator: "\n") {
                    let str = String(line)
                    if str.contains("GPU HW active residency") || str.contains("GPU active residency") {
                        let parts = str.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                        if let last = parts.last {
                            let cleaned = last.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                            if let val = Double(cleaned) {
                                cachedGPUUsage = val
                                lastGPUUsageAt = now
                                usage = val
                                break
                            }
                        }
                    }
                }
            }
        } else if cachedGPUUsage >= 0 {
            usage = cachedGPUUsage
        }

        return (name: cachedGPUName, usage: usage)
    }

    // MARK: - Uptime

    private func collectUptime() -> UInt64 {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0 {
            let bootInterval = TimeInterval(boottime.tv_sec)
            let uptime = Date().timeIntervalSince1970 - bootInterval
            return UInt64(max(0, uptime))
        }
        return 0
    }

    // MARK: - Hardware

    private func collectHardwareSummary() async -> String {
        if let cached = cachedHardwareSummary { return cached }

        async let brandTask = runSysctlString("machdep.cpu.brand_string")
        async let physTask = runSysctlString("hw.physicalcpu")
        async let logTask = runSysctlString("hw.logicalcpu")

        let brand = await brandTask ?? "Apple Silicon"
        let physCores = await physTask ?? "?"
        let logCores = await logTask ?? "?"
        let memStr = collectMemSizeString()

        let shortBrand = brand.replacingOccurrences(of: "Apple ", with: "")
        let summary = "\(shortBrand) · \(physCores) cores · \(memStr) · \(logCores) threads"
        cachedHardwareSummary = summary
        return summary
    }

    private func runSysctlString(_ name: String) async -> String? {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/usr/sbin/sysctl", arguments: ["-n", name], timeout: 2
        ), result.success else { return nil }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated func collectMemSizeString() -> String {
        var totalBytes: UInt64 = 0
        var totalSize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalBytes, &totalSize, nil, 0)
        let gb = Double(totalBytes) / 1_073_741_824
        if gb == floor(gb) { return "\(Int(gb)) GB" }
        return String(format: "%.2f GB", gb)
    }

    // MARK: - Network

    private func collectNetworkRates(now: Date) async -> StatusNetworkSnapshot {
        guard let result = try? await SystemCommandExecutor.shared.run("/usr/sbin/netstat", arguments: ["-ib"], timeout: 2), result.success else {
            return StatusNetworkSnapshot(downloadMBps: 0, uploadMBps: 0)
        }

        let lines = result.stdout.split(separator: "\n")
        var rxTotal: UInt64 = 0
        var txTotal: UInt64 = 0

        for line in lines.dropFirst() {
            let cols = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard cols.count >= 10 else { continue }
            if let ibytes = UInt64(cols[6]), let obytes = UInt64(cols[9]) {
                rxTotal += ibytes
                txTotal += obytes
            }
        }

        defer { previousNetworkBytes = (rx: rxTotal, tx: txTotal, time: now) }

        guard let previous = previousNetworkBytes else {
            return StatusNetworkSnapshot(downloadMBps: 0, uploadMBps: 0)
        }

        let elapsed = now.timeIntervalSince(previous.time)
        guard elapsed > 0 else { return StatusNetworkSnapshot(downloadMBps: 0, uploadMBps: 0) }

        let rxRate = Double(max(0, rxTotal - previous.rx)) / elapsed / 1_000_000
        let txRate = Double(max(0, txTotal - previous.tx)) / elapsed / 1_000_000
        return StatusNetworkSnapshot(downloadMBps: rxRate, uploadMBps: txRate)
    }

    // MARK: - Processes

    private func collectProcessAlerts(now: Date) async -> [StatusProcessAlert] {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/bin/ps", arguments: ["-Ao", "pid,pcpu,comm", "-r"], timeout: 2
        ), result.success else { return [] }

        let lines = result.stdout.split(separator: "\n").dropFirst(1)
        let threshold = 90.0
        let sustainedWindow: TimeInterval = 20

        var currentlyHighCPU = Set<Int>()
        var alerts: [StatusProcessAlert] = []

        for line in lines.prefix(25) {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard columns.count >= 3,
                  let pid = Int(columns[0]),
                  let cpu = Double(columns[1]) else { continue }

            let processName = columns[2]
            guard cpu >= threshold else { continue }

            currentlyHighCPU.insert(pid)
            let firstSeen = processHighCPUStart[pid] ?? now
            processHighCPUStart[pid] = firstSeen

            if now.timeIntervalSince(firstSeen) >= sustainedWindow {
                alerts.append(StatusProcessAlert(
                    processName: processName, pid: pid, cpuPercent: cpu,
                    message: "Sustained high CPU (>\(Int(threshold))%)"
                ))
            }
        }

        processHighCPUStart = processHighCPUStart.filter { currentlyHighCPU.contains($0.key) }
        return alerts
    }

    private func collectTopProcesses() async -> [StatusProcess] {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/bin/ps", arguments: ["-Ao", "pid,pcpu,rss,comm", "-r"], timeout: 2
        ), result.success else { return [] }

        let lines = result.stdout.split(separator: "\n").dropFirst(1)
        var processes: [StatusProcess] = []

        for line in lines.prefix(15) {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard columns.count >= 4,
                  let pid = Int(columns[0]),
                  let cpu = Double(columns[1]),
                  let rss = Int64(columns[2]) else { continue }
            let name = columns[3...].joined(separator: " ")
            processes.append(StatusProcess(
                name: name, pid: pid, cpuPercent: cpu, memoryMB: Double(rss) / 1024.0
            ))
        }
        return processes
    }

    // MARK: - Health Score (ported from Mole)

    private func calculateHealthScore(
        cpuUsage: Double,
        memoryUsed: Int64,
        memoryTotal: Int64,
        memoryPressure: String,
        disk: StatusDiskSnapshot,
        batteryHealth: String?,
        thermalTemp: Double?,
        diskReadMBps: Double,
        diskWriteMBps: Double,
        uptimeSecs: UInt64
    ) -> (score: Int, message: String) {
        var score = 100.0
        var issues: [String] = []

        // CPU (weight 30)
        if cpuUsage > 30 {
            if cpuUsage > 70 {
                score -= 30 * (cpuUsage - 30) / 70
                issues.append("High CPU")
            } else {
                score -= 15 * (cpuUsage - 30) / 40
            }
        }

        // Memory (weight 25)
        let memPercent = memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) * 100 : 0
        if memPercent > 50 {
            if memPercent > 80 {
                score -= 25 * (memPercent - 50) / 50
                issues.append("High Memory")
            } else {
                score -= 12.5 * (memPercent - 50) / 30
            }
        }
        switch memoryPressure {
        case "warn": score -= 5; issues.append("Memory Pressure")
        case "critical": score -= 15; issues.append("Critical Memory")
        default: break
        }

        // Disk (weight 20)
        let diskPercent = disk.totalBytes > 0 ? Double(disk.usedBytes) / Double(disk.totalBytes) * 100 : 0
        if diskPercent > 70 {
            if diskPercent > 90 { score -= 20 * (diskPercent - 70) / 30; issues.append("Disk Almost Full") }
            else { score -= 10 * (diskPercent - 70) / 20 }
        }

        // Thermal (weight 15)
        if let temp = thermalTemp, temp > 0 {
            if temp > 85 { score -= 15; issues.append("Overheating") }
            else if temp > 60 { score -= 15 * (temp - 60) / 25 }
        }

        // Disk IO (weight 10)
        let totalIO = diskReadMBps + diskWriteMBps
        if totalIO > 50 {
            if totalIO > 150 { score -= 10; issues.append("Heavy Disk IO") }
            else { score -= 10 * (totalIO - 50) / 100 }
        }

        // Battery health
        if batteryHealth == "Service Soon" { score -= 5; issues.append("Battery Service Soon") }

        // Uptime
        if uptimeSecs > 14 * 86400 { score -= 3; issues.append("Restart Recommended") }
        else if uptimeSecs > 7 * 86400 { score -= 1 }

        let finalScore = max(0, min(100, Int(score)))
        let label: String
        switch finalScore {
        case 90...: label = "Excellent"
        case 75..<90: label = "Good"
        case 60..<75: label = "Fair"
        case 40..<60: label = "Poor"
        default: label = "Critical"
        }
        let message = issues.isEmpty ? label : "\(label): \(issues.prefix(2).joined(separator: ", "))"
        return (finalScore, message)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class StatusFeatureViewModel {
    var snapshot: StatusSnapshot?
    var isRunning: Bool = false

    // History for sparklines (capped at 60 values = ~1 minute)
    var cpuHistory: [Double] = []
    var memHistory: [Double] = []
    var gpuHistory: [Double] = []
    var netDownHistory: [Double] = []
    var diskReadHistory: [Double] = []
    var diskWriteHistory: [Double] = []

    private let historyCapacity = 60
    private var loopTask: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        isRunning = true

        loopTask = Task {
            while !Task.isCancelled {
                let snap = await StatusService.shared.collect()
                self.snapshot = snap
                self.appendHistory(snap)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func appendHistory(_ snap: StatusSnapshot) {
        func push(_ history: inout [Double], _ value: Double) {
            history.append(value)
            if history.count > historyCapacity { history.removeFirst() }
        }
        push(&cpuHistory, snap.cpuUsagePercent)
        push(&memHistory, snap.memoryUsedPercent)
        push(&gpuHistory, snap.gpuUsagePercent ?? 0)
        push(&netDownHistory, snap.network.downloadMBps)
        push(&diskReadHistory, snap.diskReadMBps)
        push(&diskWriteHistory, snap.diskWriteMBps)
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
    }
}
