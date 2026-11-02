import SwiftUI

@main
struct APIMonitoringApp: App {
    @StateObject private var store = AccountStore()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(store)
        }
    }
}
