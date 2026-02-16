import Foundation
import GameKit
import SwiftUI

// MARK: - Match Message Types

enum MessageType: Int, Codable, Sendable {
    case gameSetup
    case drawCard
    case selectTarget
    case attack
    case attackResult
    case continueOrStay
    case nextRound
    case syncState
}

struct GameMessage: Codable, Sendable {
    let type: MessageType
    let playerIndex: Int
    var targetIndex: Int?
    var guessedNumber: Int?
    var guessedColor: CardColor?
    var continueAttack: Bool?
    var deckSeed: Int?
    var firstPlayer: Int?
}

// MARK: - Multiplayer Service

@Observable
final class MultiplayerService: NSObject, @unchecked Sendable {
    var isAuthenticated = false
    var isMatchmaking = false
    var isMatched = false
    var localPlayerIndex: Int = 0
    var errorMessage: String?
    var localPlayerName: String = "プレイヤー"
    var remotePlayerName: String = "相手"
    var localPlayerRating: Int = 1500

    private var match: GKMatch?
    private var matchmakerVC: GKMatchmakerViewController?
    var gameState: GameState?

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = "認証エラー: \(error.localizedDescription)"
                    return
                }
                if viewController != nil {
                    // Present the authentication view controller
                    // In SwiftUI, we handle this differently
                    return
                }
                if GKLocalPlayer.local.isAuthenticated {
                    self.isAuthenticated = true
                    self.localPlayerName = GKLocalPlayer.local.displayName
                    self.loadRating()
                }
            }
        }
    }

    private func loadRating() {
        // Load from UserDefaults as a simple persistence for rating
        localPlayerRating = UserDefaults.standard.integer(forKey: "playerRating")
        if localPlayerRating == 0 {
            localPlayerRating = 1500
            UserDefaults.standard.set(1500, forKey: "playerRating")
        }
    }

    func saveRating(_ newRating: Int) {
        localPlayerRating = newRating
        UserDefaults.standard.set(newRating, forKey: "playerRating")
    }

    // MARK: - Matchmaking

    func findMatch() {
        guard isAuthenticated else {
            errorMessage = "Game Centerにサインインしてください。"
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2

        isMatchmaking = true
        errorMessage = nil

        GKMatchmaker.shared().findMatch(for: request) { [weak self] match, error in
            Task { @MainActor in
                guard let self else { return }
                self.isMatchmaking = false

                if let error {
                    self.errorMessage = "マッチメイキングエラー: \(error.localizedDescription)"
                    return
                }

                guard let match else {
                    self.errorMessage = "マッチが見つかりませんでした。"
                    return
                }

                self.match = match
                match.delegate = self
                self.isMatched = true
                self.setupGame()
            }
        }
    }

    func cancelMatchmaking() {
        GKMatchmaker.shared().cancel()
        isMatchmaking = false
    }

    func disconnect() {
        match?.disconnect()
        match = nil
        isMatched = false
        gameState = nil
    }

    // MARK: - Game Setup

    private func setupGame() {
        guard let match else { return }

        let localID = GKLocalPlayer.local.teamPlayerID
        let remoteIDs = match.players.map(\.teamPlayerID)

        // Determine player index by comparing IDs lexicographically
        if let remoteID = remoteIDs.first {
            localPlayerIndex = localID < remoteID ? 0 : 1
            remotePlayerName = match.players.first?.displayName ?? "相手"
        }

        // Player 0 generates the seed and sends setup
        if localPlayerIndex == 0 {
            let seed = Int.random(in: 0...Int.max)
            let firstPlayer = Int.random(in: 0...1)

            let state = GameState()
            applySeededSetup(state: state, seed: seed, firstPlayer: firstPlayer)
            gameState = state

            let msg = GameMessage(
                type: .gameSetup,
                playerIndex: 0,
                deckSeed: seed,
                firstPlayer: firstPlayer
            )
            sendMessage(msg)
        }
    }

    private func applySeededSetup(state: GameState, seed: Int, firstPlayer: Int) {
        // Build deck with deterministic shuffle using seed
        var generator = SeededRandomNumberGenerator(seed: UInt64(seed))
        var cards: [Card] = []
        for number in 0...11 {
            cards.append(Card(number: number, color: .black))
            cards.append(Card(number: number, color: .white))
        }
        cards.shuffle(using: &generator)

        let name0 = localPlayerIndex == 0 ? localPlayerName : remotePlayerName
        let name1 = localPlayerIndex == 1 ? localPlayerName : remotePlayerName

        state.players = [
            Player(name: name0),
            Player(name: name1)
        ]
        state.deck = cards
        state.firstPlayerOfRound = firstPlayer
        state.currentRound = 1
        state.roundScores = [0, 0]
        state.isGameOver = false

        // Each player draws 4 cards
        for _ in 0..<4 {
            if !state.deck.isEmpty {
                let card = state.deck.removeFirst()
                state.players[0].insertSorted(card)
            }
            if !state.deck.isEmpty {
                let card = state.deck.removeFirst()
                state.players[1].insertSorted(card)
            }
        }

        state.currentPlayerIndex = firstPlayer
        state.drawnCard = nil
        state.phase = .drawingCard
        state.message = "\(state.players[firstPlayer].name) のターンです。カードを引いてください。"
    }

    // MARK: - Send Message

    func sendMessage(_ message: GameMessage) {
        guard let match else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            errorMessage = "送信エラー: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions

    func sendDrawCard() {
        let msg = GameMessage(type: .drawCard, playerIndex: localPlayerIndex)
        sendMessage(msg)
        gameState?.drawCard()
    }

    func sendSelectTarget(index: Int) {
        let msg = GameMessage(type: .selectTarget, playerIndex: localPlayerIndex, targetIndex: index)
        sendMessage(msg)
        gameState?.selectTarget(index: index)
    }

    func sendAttack(number: Int, color: CardColor) {
        let msg = GameMessage(type: .attack, playerIndex: localPlayerIndex, guessedNumber: number, guessedColor: color)
        sendMessage(msg)
        gameState?.attack(guessedNumber: number, guessedColor: color)
    }

    func sendContinueOrStay(continueAttack: Bool) {
        let msg = GameMessage(type: .continueOrStay, playerIndex: localPlayerIndex, continueAttack: continueAttack)
        sendMessage(msg)
        if continueAttack {
            gameState?.continueAttack()
        } else {
            gameState?.stay()
        }
    }

    func sendAcknowledgeMiss() {
        let msg = GameMessage(type: .attackResult, playerIndex: localPlayerIndex)
        sendMessage(msg)
        gameState?.acknowledgesMiss()
    }

    func sendNextRound() {
        let msg = GameMessage(type: .nextRound, playerIndex: localPlayerIndex)
        sendMessage(msg)
        gameState?.startNextRound()
    }

    // MARK: - Handle Remote Message

    private func handleRemoteMessage(_ message: GameMessage) {
        guard let gameState else { return }

        switch message.type {
        case .gameSetup:
            if let seed = message.deckSeed, let firstPlayer = message.firstPlayer {
                let state = GameState()
                applySeededSetup(state: state, seed: seed, firstPlayer: firstPlayer)
                self.gameState = state
            }
        case .drawCard:
            gameState.drawCard()
        case .selectTarget:
            if let idx = message.targetIndex {
                gameState.selectTarget(index: idx)
            }
        case .attack:
            if let number = message.guessedNumber, let color = message.guessedColor {
                gameState.attack(guessedNumber: number, guessedColor: color)
            }
        case .attackResult:
            gameState.acknowledgesMiss()
        case .continueOrStay:
            if let cont = message.continueAttack {
                if cont {
                    gameState.continueAttack()
                } else {
                    gameState.stay()
                }
            }
        case .nextRound:
            gameState.startNextRound()
        case .syncState:
            break
        }
    }
}

// MARK: - GKMatchDelegate

extension MultiplayerService: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)
            Task { @MainActor in
                self.handleRemoteMessage(message)
            }
        } catch {
            Task { @MainActor in
                self.errorMessage = "受信エラー: \(error.localizedDescription)"
            }
        }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            switch state {
            case .disconnected:
                self.errorMessage = "相手が切断しました。"
                self.isMatched = false
            default:
                break
            }
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor in
            self.errorMessage = "接続エラー: \(error?.localizedDescription ?? "不明")"
            self.isMatched = false
        }
    }
}

// MARK: - Seeded RNG

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
