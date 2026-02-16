import SwiftUI

@main
struct NumberDeductionApp: App {
    @State private var multiplayerService = MultiplayerService()

    var body: some Scene {
        WindowGroup {
            ContentView(multiplayerService: multiplayerService)
                .onAppear {
                    multiplayerService.authenticate()
                }
        }
    }
}

struct ContentView: View {
    let multiplayerService: MultiplayerService

    var body: some View {
        if multiplayerService.isMatched {
            GameView(multiplayerService: multiplayerService)
        } else {
            HomeView(multiplayerService: multiplayerService)
        }
    }
}
