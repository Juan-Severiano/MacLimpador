import Foundation
import IOKit.ps
import Observation

actor StatusService {
    static let shared = StatusService()

    private var previousCPUSample: host_cpu_load_info?
    private var previousNetworkBytes: (rx: UInt64, tx: UInt64, time: Date)?
    private var processHighCPUStart: [Int: Date] = [:]

    private init() {}

    func collect() async -> StatusSnapshot {
        let now = Date()

        let hostName = Host.current().localizedName ?? "Mac"
        let cpuUsage = collectCPUUsagePercent()
        let memory = collectMemoryUsage()
        let disk = collectDiskUsage()
        let battery = collectBatteryInfo()
        let network = await collectNetworkRates(now: now)
        let alerts = await collectProcessAlerts(now: now)

        let healthScore = calculateHealthScore(
            cpuUsage: cpuUsage,
            memoryUsed: memory.used,
            memoryTotal: memory.total,
            disk: disk,
            batteryPercent: battery.percent
        )

        return StatusSnapshot(
            collectedAt: now,
            hostName: hostName,
            healthScore: healthScore,
            cpuUsagePercent: cpuUsage,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            disk: disk,
            batteryPercent: battery.percent,
            batteryCharging: battery.isCharging,
            network: network,
            processAlerts: alerts
        )
    }

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

        defer {
            previousNetworkBytes = (rx: rxTotal, tx: txTotal, time: now)
        }

        guard let previous = previousNetworkBytes else {
            return StatusNetworkSnapshot(downloadMBps: 0, uploadMBps: 0)
        }

        let elapsed = now.timeIntervalSince(previous.time)
        guard elapsed > 0 else {
            return StatusNetworkSnapshot(downloadMBps: 0, uploadMBps: 0)
        }

        let rxRate = Double(max(0, rxTotal - previous.rx)) / elapsed / 1_000_000
        let txRate = Double(max(0, txTotal - previous.tx)) / elapsed / 1_000_000

        return StatusNetworkSnapshot(downloadMBps: rxRate, uploadMBps: txRate)
    }

    private func collectProcessAlerts(now: Date) async -> [StatusProcessAlert] {
        guard let result = try? await SystemCommandExecutor.shared.run(
            "/bin/ps",
            arguments: ["-Ao", "pid,pcpu,comm", "-r"],
            timeout: 2
        ), result.success else {
            return []
        }

        let lines = result.stdout.split(separator: "\n").dropFirst(1)
        let threshold = 90.0
        let sustainedWindow: TimeInterval = 20

        var currentlyHighCPU = Set<Int>()
        var alerts: [StatusProcessAlert] = []

        for line in lines.prefix(25) {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard columns.count >= 3,
                  let pid = Int(columns[0]),
                  let cpu = Double(columns[1]) else {
                continue
            }

            let processName = columns[2]
            guard cpu >= threshold else { continue }

            currentlyHighCPU.insert(pid)
            let firstSeen = processHighCPUStart[pid] ?? now
            processHighCPUStart[pid] = firstSeen

            if now.timeIntervalSince(firstSeen) >= sustainedWindow {
                alerts.append(
                    StatusProcessAlert(
                        processName: processName,
                        pid: pid,
                        cpuPercent: cpu,
                        message: "Sustained high CPU (>\(Int(threshold))%)"
                    )
                )
            }
        }

        // Clear stale entries.
        processHighCPUStart = processHighCPUStart.filter { currentlyHighCPU.contains($0.key) }

        return alerts
    }

    private func calculateHealthScore(
        cpuUsage: Double,
        memoryUsed: Int64,
        memoryTotal: Int64,
        disk: StatusDiskSnapshot,
        batteryPercent: Double?
    ) -> Int {
        var score = 100

        if cpuUsage > 85 {
            score -= 30
        } else if cpuUsage > 65 {
            score -= 15
        }

        if memoryTotal > 0 {
            let memoryPercent = (Double(memoryUsed) / Double(memoryTotal)) * 100
            if memoryPercent > 90 {
                score -= 30
            } else if memoryPercent > 75 {
                score -= 15
            }
        }

        if disk.totalBytes > 0 {
            let diskUsedPercent = (Double(disk.usedBytes) / Double(disk.totalBytes)) * 100
            if diskUsedPercent > 92 {
                score -= 20
            } else if diskUsedPercent > 80 {
                score -= 10
            }
        }

        if let batteryPercent, batteryPercent < 15 {
            score -= 10
        }

        return max(0, min(100, score))
    }
}

@Observable
@MainActor
final class StatusFeatureViewModel {
    var snapshot: StatusSnapshot?
    var isRunning: Bool = false

    private var loopTask: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        isRunning = true

        loopTask = Task {
            while !Task.isCancelled {
                let snap = await StatusService.shared.collect()
                self.snapshot = snap
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
    }
}
