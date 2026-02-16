import SwiftUI

enum AppScreen {
    case home
    case singlePlayer
    case multiplayer
}

@main
struct NumberDeductionApp: App {
    @State private var multiplayerService = MultiplayerService()
    @State private var currentScreen: AppScreen = .home

    var body: some Scene {
        WindowGroup {
            switch currentScreen {
            case .home:
                HomeView(
                    multiplayerService: multiplayerService,
                    onStartSinglePlayer: {
                        currentScreen = .singlePlayer
                    }
                )
                .onChange(of: multiplayerService.isMatched) {
                    if multiplayerService.isMatched {
                        currentScreen = .multiplayer
                    }
                }

            case .singlePlayer:
                SinglePlayerGameView {
                    currentScreen = .home
                }

            case .multiplayer:
                GameView(multiplayerService: multiplayerService)
                    .onChange(of: multiplayerService.isMatched) {
                        if !multiplayerService.isMatched {
                            currentScreen = .home
                        }
                    }
            }
        }
    }
}
