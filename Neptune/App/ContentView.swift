import SwiftUI

struct ContentView: View {
    @EnvironmentObject var agentWatcher: AgentStateWatcher
    @EnvironmentObject var petMapper: PetStateMapper
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        DashboardView(
            agentWatcher: agentWatcher,
            petMapper: petMapper,
            settings: settings
        )
    }
}
