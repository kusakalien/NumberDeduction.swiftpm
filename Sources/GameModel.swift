import Foundation
import SwiftUI

// MARK: - Card

enum CardColor: String, Codable, Sendable {
    case black
    case white
}

struct Card: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let number: Int
    let color: CardColor
    var isOpen: Bool

    init(number: Int, color: CardColor, isOpen: Bool = false) {
        self.id = UUID()
        self.number = number
        self.color = color
        self.isOpen = isOpen
    }

    /// Sort value: black < white for same number
    var sortValue: Int {
        number * 2 + (color == .white ? 1 : 0)
    }
}

// MARK: - Player

struct Player: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var cards: [Card]
    var rating: Int

    init(name: String, rating: Int = 1500) {
        self.id = UUID()
        self.name = name
        self.cards = []
        self.rating = rating
    }

    var allOpen: Bool {
        cards.allSatisfy(\.isOpen)
    }

    mutating func insertSorted(_ card: Card) {
        cards.append(card)
        cards.sort { $0.sortValue < $1.sortValue }
    }
}

// MARK: - Attack Result

enum AttackResult: Sendable {
    case hit
    case miss
}

// MARK: - Turn Phase

enum TurnPhase: Sendable, Equatable {
    case drawingCard
    case choosingTarget
    case guessing(targetIndex: Int)
    case attackResult(AttackResult)
    case choosingContinueOrStay
    case roundOver(winnerIndex: Int)
    case gameOver(winnerIndex: Int)
}

// MARK: - Game State

@Observable
final class GameState: @unchecked Sendable {
    var players: [Player] = []
    var deck: [Card] = []
    var currentPlayerIndex: Int = 0
    var phase: TurnPhase = .drawingCard
    var drawnCard: Card? = nil
    var roundScores: [Int] = [0, 0] // consecutive round wins
    var currentRound: Int = 1
    var firstPlayerOfRound: Int = 0
    var message: String = ""
    var isGameOver: Bool = false
    var gameWinner: Int? = nil

    var currentPlayer: Player { players[currentPlayerIndex] }
    var opponentIndex: Int { 1 - currentPlayerIndex }
    var opponent: Player { players[opponentIndex] }

    // MARK: - Deck Setup

    func buildDeck() -> [Card] {
        var cards: [Card] = []
        for number in 0...11 {
            cards.append(Card(number: number, color: .black))
            cards.append(Card(number: number, color: .white))
        }
        return cards.shuffled()
    }

    func startNewGame(player1Name: String, player2Name: String, p1Rating: Int = 1500, p2Rating: Int = 1500) {
        players = [
            Player(name: player1Name, rating: p1Rating),
            Player(name: player2Name, rating: p2Rating)
        ]
        roundScores = [0, 0]
        currentRound = 1
        firstPlayerOfRound = Int.random(in: 0...1)
        isGameOver = false
        gameWinner = nil
        startRound()
    }

    func startRound() {
        deck = buildDeck()
        players[0].cards = []
        players[1].cards = []

        // Each player draws 4 cards
        for _ in 0..<4 {
            if let card = drawFromDeck() {
                players[0].insertSorted(card)
            }
            if let card = drawFromDeck() {
                players[1].insertSorted(card)
            }
        }

        currentPlayerIndex = firstPlayerOfRound
        drawnCard = nil
        phase = .drawingCard
        message = "\(players[currentPlayerIndex].name) のターンです。カードを引いてください。"
    }

    private func drawFromDeck() -> Card? {
        guard !deck.isEmpty else { return nil }
        return deck.removeFirst()
    }

    // MARK: - Actions

    func drawCard() {
        guard phase == .drawingCard else { return }
        if let card = drawFromDeck() {
            drawnCard = card
            phase = .choosingTarget
            message = "相手のカードを選んでアタックしてください。"
        } else {
            // No cards left in deck — end round by comparing open cards
            endRoundByDeckEmpty()
        }
    }

    func selectTarget(index: Int) {
        guard phase == .choosingTarget else { return }
        let targetCard = players[opponentIndex].cards[index]
        if targetCard.isOpen {
            message = "そのカードは既にオープンされています。別のカードを選んでください。"
            return
        }
        phase = .guessing(targetIndex: index)
        message = "数字を推理してください。"
    }

    func attack(guessedNumber: Int) {
        guard case .guessing(let targetIndex) = phase else { return }
        let targetCard = players[opponentIndex].cards[targetIndex]

        if targetCard.number == guessedNumber {
            // Hit
            players[opponentIndex].cards[targetIndex].isOpen = true
            phase = .attackResult(.hit)
            message = "イエス！ 正解です！"

            if players[opponentIndex].allOpen {
                handleRoundWin(winnerIndex: currentPlayerIndex)
                return
            }

            // After a short display, move to choose continue or stay
            phase = .choosingContinueOrStay
        } else {
            // Miss
            phase = .attackResult(.miss)
            message = "ノー！ はずれです。"
        }
    }

    func continueAttack() {
        guard phase == .choosingContinueOrStay else { return }
        phase = .choosingTarget
        message = "続けてアタック！相手のカードを選んでください。"
    }

    func stay() {
        guard phase == .choosingContinueOrStay else { return }
        if var card = drawnCard {
            card.isOpen = false
            players[currentPlayerIndex].insertSorted(card)
            drawnCard = nil
        }
        switchTurn()
    }

    func acknowledgesMiss() {
        guard case .attackResult(.miss) = phase else { return }
        if var card = drawnCard {
            card.isOpen = true
            players[currentPlayerIndex].insertSorted(card)
            drawnCard = nil
        }
        switchTurn()
    }

    private func switchTurn() {
        currentPlayerIndex = opponentIndex
        phase = .drawingCard
        message = "\(players[currentPlayerIndex].name) のターンです。カードを引いてください。"
    }

    private func handleRoundWin(winnerIndex: Int) {
        roundScores[winnerIndex] += 1
        let loserIndex = 1 - winnerIndex

        // Check if winner has 2 consecutive round wins
        if roundScores[winnerIndex] >= 2 {
            phase = .gameOver(winnerIndex: winnerIndex)
            message = "\(players[winnerIndex].name) が2ラウンド連取で勝利！"
            isGameOver = true
            gameWinner = winnerIndex
            return
        }

        // Reset loser's consecutive wins
        roundScores[loserIndex] = 0

        phase = .roundOver(winnerIndex: winnerIndex)
        message = "ラウンド\(currentRound): \(players[winnerIndex].name) の勝ち！"
    }

    func startNextRound() {
        currentRound += 1
        firstPlayerOfRound = 1 - firstPlayerOfRound
        startRound()
    }

    private func endRoundByDeckEmpty() {
        // Count open cards — fewer open cards wins
        let open0 = players[0].cards.filter(\.isOpen).count
        let open1 = players[1].cards.filter(\.isOpen).count
        if open0 < open1 {
            handleRoundWin(winnerIndex: 0)
        } else if open1 < open0 {
            handleRoundWin(winnerIndex: 1)
        } else {
            // Tie — attacker wins
            handleRoundWin(winnerIndex: currentPlayerIndex)
        }
    }

    // MARK: - Rating

    static func calculateNewRatings(winnerRating: Int, loserRating: Int, k: Double = 32) -> (winnerNew: Int, loserNew: Int) {
        let expectedWin = 1.0 / (1.0 + pow(10.0, Double(loserRating - winnerRating) / 400.0))
        let expectedLose = 1.0 - expectedWin
        let newWinner = winnerRating + Int(k * (1.0 - expectedWin))
        let newLoser = loserRating + Int(k * (0.0 - expectedLose))
        return (newWinner, newLoser)
    }
}
