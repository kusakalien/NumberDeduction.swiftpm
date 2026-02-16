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

@MainActor @Observable
final class MultiplayerService: NSObject {
    var isAuthenticated = false
    var isMatchmaking = false
    var isMatched = false
    var localPlayerIndex: Int = 0
    var errorMessage: String?
    var localPlayerName: String = "プレイヤー"
    var remotePlayerName: String = "相手"
    var localPlayerRating: Int = 1500

    private var match: GKMatch?
    var gameState: GameState?

    nonisolated override init() {
        super.init()
    }

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            let errMsg = error?.localizedDescription
            let isAuth = GKLocalPlayer.local.isAuthenticated
            let displayName = GKLocalPlayer.local.displayName
            Task { @MainActor in
                guard let self else { return }
                if let errMsg {
                    self.errorMessage = "認証エラー: \(errMsg)"
                    return
                }
                if viewController != nil {
                    return
                }
                if isAuth {
                    self.isAuthenticated = true
                    self.localPlayerName = displayName
                    self.loadRating()
                }
            }
        }
    }

    private func loadRating() {
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
            let errMsg = error?.localizedDescription
            let playerName = match?.players.first?.displayName
            let playerIDs = match?.players.map(\.teamPlayerID)
            let localID = GKLocalPlayer.local.teamPlayerID
            Task { @MainActor in
                guard let self else { return }
                self.isMatchmaking = false

                if let errMsg {
                    self.errorMessage = "マッチメイキングエラー: \(errMsg)"
                    return
                }

                guard let match else {
                    self.errorMessage = "マッチが見つかりませんでした。"
                    return
                }

                self.match = match
                match.delegate = self
                self.isMatched = true

                // Determine player index
                if let remoteID = playerIDs?.first {
                    self.localPlayerIndex = localID < remoteID ? 0 : 1
                    self.remotePlayerName = playerName ?? "相手"
                }

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
        guard match != nil else { return }

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

extension MultiplayerService: @preconcurrency GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        let decoded = try? JSONDecoder().decode(GameMessage.self, from: data)
        Task { @MainActor in
            if let decoded {
                self.handleRemoteMessage(decoded)
            } else {
                self.errorMessage = "受信エラー: メッセージのデコードに失敗しました"
            }
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
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

    nonisolated func match(_ match: GKMatch, didFailWithError error: (any Error)?) {
        let errMsg = error?.localizedDescription ?? "不明"
        Task { @MainActor in
            self.errorMessage = "接続エラー: \(errMsg)"
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
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
