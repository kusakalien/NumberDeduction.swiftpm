import SwiftUI

enum AppScreen: Equatable {
    case home
    case singlePlayer
    case multiplayer
}

@Observable
final class AppRouter {
    var currentScreen: AppScreen = .home
}

@main
struct NumberDeductionApp: App {
    @State private var router = AppRouter()
    @State private var multiplayerService = MultiplayerService()

    var body: some Scene {
        WindowGroup {
            ContentView(router: router, multiplayerService: multiplayerService)
        }
    }
}

struct ContentView: View {
    @Bindable var router: AppRouter
    let multiplayerService: MultiplayerService

    var body: some View {
        ZStack {
            switch router.currentScreen {
            case .home:
                HomeView(
                    multiplayerService: multiplayerService,
                    onStartSinglePlayer: {
                        router.currentScreen = .singlePlayer
                    }
                )

            case .singlePlayer:
                SinglePlayerGameView {
                    router.currentScreen = .home
                }

            case .multiplayer:
                GameView(multiplayerService: multiplayerService)
            }
        }
        .onChange(of: multiplayerService.isMatched) {
            if multiplayerService.isMatched {
                router.currentScreen = .multiplayer
            } else if router.currentScreen == .multiplayer {
                router.currentScreen = .home
            }
        }
    }
}
