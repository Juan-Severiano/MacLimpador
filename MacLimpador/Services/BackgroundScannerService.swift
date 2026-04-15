import Foundation
import UserNotifications

final class BackgroundScannerService {
    static let shared = BackgroundScannerService()
    
    private var scanTimer: Timer?
    private let userDefaultsKey = "backgroundScanSettings"
    
    private init() {}
    
    struct ScanSettings: Codable {
        var isEnabled: Bool = false
        var frequency: ScanFrequency = .weekly
        var junkThresholdGB: Int64 = 5 // GB
        var lastScanDate: Date?
    }
    
    enum ScanFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var interval: TimeInterval {
            switch self {
            case .daily: return 86400
            case .weekly: return 604800
            case .monthly: return 2592000
            }
        }
    }
    
    func startBackgroundScanning() {
        let settings = loadSettings()
        guard settings.isEnabled else { return }
        
        stopBackgroundScanning()
        
        scanTimer = Timer.scheduledTimer(
            withTimeInterval: settings.frequency.interval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.runScheduledScan()
            }
        }
    }
    
    func stopBackgroundScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    func updateSettings(_ settings: ScanSettings) {
        saveSettings(settings)
        
        if settings.isEnabled {
            startBackgroundScanning()
        } else {
            stopBackgroundScanning()
        }
    }
    
    func loadSettings() -> ScanSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(ScanSettings.self, from: data) else {
            return ScanSettings()
        }
        return settings
    }
    
    private func saveSettings(_ settings: ScanSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func runScheduledScan() async {
        var settings = loadSettings()
        settings.lastScanDate = Date()
        saveSettings(settings)
        
        // Run quick scan
        let results = try? await StorageScanner.shared.scan()
        
        guard let results = results else { return }
        
        let totalJunkSize = results
            .filter { $0.confidence > 0.5 }
            .reduce(0) { $0 + $1.size }
        
        let threshold = settings.junkThresholdGB * 1_000_000_000
        
        if totalJunkSize > threshold {
            await sendNotification(
                title: "Cleanup Recommended",
                body: "Found \(ByteCountFormatter.string(fromByteCount: totalJunkSize, countStyle: .file)) of junk files"
            )
        }
    }
    
    private func sendNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return true
        } catch {
            return false
        }
    }
}