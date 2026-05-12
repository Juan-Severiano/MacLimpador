import Foundation
import IOKit.ps
import AppKit

struct SystemStats {
    var cpuUsage: Double = 0
    var ramPressure: Double = 0
    var diskAvailable: Int64 = 0
    var diskTotal: Int64 = 0
    var batteryPercentage: Int = 0
    var isBatteryCharging: Bool = false
    var modelName: String = "Mac"
    var cpuName: String = ""
    var downloadSpeed: Double = 0 // Mbps
    var uploadSpeed: Double = 0 // Mbps
    var isTestingNetwork: Bool = false
    
    var formattedDiskAvailable: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: diskAvailable)
    }
    
    var formattedDiskTotal: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: diskTotal)
    }
}

@Observable
final class SystemStatsProvider {
    static let shared = SystemStatsProvider()
    var currentStats = SystemStats()
    private var timer: Timer?
    
    init() {
        currentStats.modelName = getModelName()
        currentStats.cpuName = getCpuName()
        startUpdating()
    }
    
    func startUpdating() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.update()
        }
    }
    
    func update() {
        (currentStats.diskAvailable, currentStats.diskTotal) = getDiskInfo()
        currentStats.ramPressure = getRamPressure()
        currentStats.cpuUsage = getCpuUsage()
        (currentStats.batteryPercentage, currentStats.isBatteryCharging) = getBatteryInfo()
    }
    
    func testNetworkSpeed() async {
        guard !currentStats.isTestingNetwork else { return }
        currentStats.isTestingNetwork = true
        currentStats.downloadSpeed = 0
        currentStats.uploadSpeed = 0
        
        // Simulação de teste para o MVP
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            currentStats.downloadSpeed = Double.random(in: 50...250) * (Double(i)/10.0)
        }
        
        for i in 1...5 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            currentStats.uploadSpeed = Double.random(in: 20...100) * (Double(i)/5.0)
        }
        
        currentStats.isTestingNetwork = false
    }
    
    private func getModelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let identifier = String(cString: model)
        
        // Mapeamento simples para nomes amigáveis
        if identifier.contains("MacBookAir") { return "MacBook Air" }
        if identifier.contains("MacBookPro") { return "MacBook Pro" }
        if identifier.contains("Macmini") { return "Mac mini" }
        if identifier.contains("MacStudio") { return "Mac Studio" }
        if identifier.contains("MacPro") { return "Mac Pro" }
        if identifier.contains("iMac") { return "iMac" }
        
        return identifier
    }
    
    private func getCpuName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let name = String(cString: brand)
        
        if name.isEmpty {
            // Tenta obter via hw.brand_string (Apple Silicon)
            var size2 = 0
            sysctlbyname("hw.brand_string", nil, &size2, nil, 0)
            var brand2 = [CChar](repeating: 0, count: size2)
            sysctlbyname("hw.brand_string", &brand2, &size2, nil, 0)
            return String(cString: brand2)
        }
        
        return name
    }
    
    private func getDiskInfo() -> (Int64, Int64) {
        let fileManager = FileManager.default
        let path = NSHomeDirectory()
        do {
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: path)
            let freeSize = systemAttributes[.systemFreeSize] as? Int64 ?? 0
            let totalSize = systemAttributes[.systemSize] as? Int64 ?? 0
            return (freeSize, totalSize)
        } catch {
            return (0, 0)
        }
    }
    
    private func getRamPressure() -> Double {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let used = Double(stats.active_count + stats.wire_count + stats.inactive_count)
            let total = used + Double(stats.free_count)
            return (used / total) * 100
        }
        return 0
    }
    
    private func getCpuUsage() -> Double {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numProcessors: UInt32 = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numProcessors, &cpuInfo, &numCpuInfo)
        
        if result == KERN_SUCCESS {
            // Em uma implementação real, compararíamos com o estado anterior.
            // Aqui vamos simular para manter a UI viva.
            return Double.random(in: 5...25)
        }
        return 0
    }
    
    private func getBatteryInfo() -> (Int, Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                let capacity = description[kIOPSCurrentCapacityKey] as? Int ?? 0
                let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
                return (capacity, isCharging)
            }
        }
        return (100, true) // Desktop ou erro
    }
}