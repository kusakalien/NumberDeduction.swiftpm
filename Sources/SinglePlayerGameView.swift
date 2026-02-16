import SwiftUI

struct SinglePlayerGameView: View {
    @State private var game = GameState()
    @State private var cpu = CPUPlayer()
    @State private var selectedNumber: Int = 0
    @State private var selectedColor: CardColor = .black
    @State private var cpuThinking = false
    @State private var showReturnAlert = false

    let onExit: () -> Void

    private let localIndex = 0
    private let cpuIndex = 1

    private var isMyTurn: Bool {
        game.currentPlayerIndex == localIndex
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    showReturnAlert = true
                } label: {
                    Image(systemName: "chevron.left")
                    Text("戻る")
                }

                Spacer()

                Text("ラウンド \(game.currentRound)")
                    .font(.caption.bold())

                Spacer()

                Text("\(game.roundScores[0]) - \(game.roundScores[1])")
                    .font(.caption.bold())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Opponent (CPU) area
            PlayerHandView(
                player: game.players[cpuIndex],
                isLocalPlayer: false,
                highlightedIndex: targetHighlightIndex(),
                onCardTap: isMyTurn && game.phase == .choosingTarget ? { index in
                    game.selectTarget(index: index)
                } : nil
            )

            Divider()

            // Center area
            ScrollView {
                VStack(spacing: 12) {
                    // Message
                    Text(game.message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .frame(minHeight: 36)

                    if cpuThinking {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("CPUが考えています...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Drawn card + Deck
                    HStack(spacing: 24) {
                        if let drawnCard = game.drawnCard, isMyTurn {
                            VStack(spacing: 4) {
                                Text("引いたカード")
                                    .font(.caption2)
                                DrawnCardView(card: drawnCard, isFaceUp: true)
                            }
                        }

                        DeckView(remainingCards: game.deck.count) {
                            if isMyTurn && game.phase == .drawingCard {
                                game.drawCard()
                                updateCPUKnowledge()
                            }
                        }
                        .disabled(!isMyTurn || game.phase != .drawingCard)
                    }

                    // Action area
                    actionArea()
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Local player area
            PlayerHandView(
                player: game.players[localIndex],
                isLocalPlayer: true
            )

            if !isMyTurn && !cpuThinking {
                Text("CPUのターンです")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            startGame()
        }
        .alert("ゲームを終了しますか？", isPresented: $showReturnAlert) {
            Button("終了", role: .destructive) { onExit() }
            Button("続ける", role: .cancel) { }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionArea() -> some View {
        switch game.phase {
        case .guessing:
            if isMyTurn {
                NumberColorPicker(
                    selectedNumber: $selectedNumber,
                    selectedColor: $selectedColor,
                    onConfirm: {
                        game.attack(guessedNumber: selectedNumber, guessedColor: selectedColor)
                        updateCPUKnowledge()
                        checkCPUTurnAfterDelay()
                    }
                )
                .padding(.horizontal)
            }

        case .attackResult(let result):
            if result == .miss && isMyTurn {
                Button("確認") {
                    game.acknowledgesMiss()
                    updateCPUKnowledge()
                    scheduleCPUTurn()
                }
                .buttonStyle(.borderedProminent)
            }

        case .choosingContinueOrStay:
            if isMyTurn {
                HStack(spacing: 20) {
                    Button {
                        game.continueAttack()
                    } label: {
                        Label("続けてアタック", systemImage: "flame.fill")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button {
                        game.stay()
                        updateCPUKnowledge()
                        scheduleCPUTurn()
                    } label: {
                        Label("ステイ", systemImage: "hand.raised.fill")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }

        case .roundOver(let winnerIndex):
            VStack(spacing: 12) {
                Text(winnerIndex == localIndex ? "ラウンド勝利！" : "ラウンド敗北...")
                    .font(.title2.bold())
                    .foregroundStyle(winnerIndex == localIndex ? .green : .red)

                Button("次のラウンドへ") {
                    game.startNextRound()
                    cpu.reset()
                    updateCPUKnowledge()
                    if !isMyTurn {
                        scheduleCPUTurn()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

        case .gameOver(let winnerIndex):
            VStack(spacing: 12) {
                Text(winnerIndex == localIndex ? "勝利！" : "敗北...")
                    .font(.largeTitle.bold())
                    .foregroundStyle(winnerIndex == localIndex ? .green : .red)

                Button("ホームに戻る") {
                    onExit()
                }
                .buttonStyle(.borderedProminent)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Game Setup

    private func startGame() {
        game.startNewGame(player1Name: "あなた", player2Name: "CPU")
        cpu.reset()
        updateCPUKnowledge()

        if !isMyTurn {
            scheduleCPUTurn()
        }
    }

    // MARK: - CPU Turn Logic

    private func updateCPUKnowledge() {
        cpu.markKnownCards(from: game.players)
        // CPU knows its own cards
        for card in game.players[cpuIndex].cards {
            cpu.markKnown(card: card)
        }
        // CPU knows drawn card if it's CPU's turn
        if let drawn = game.drawnCard, game.currentPlayerIndex == cpuIndex {
            cpu.markKnown(card: drawn)
        }
    }

    private func scheduleCPUTurn() {
        guard game.currentPlayerIndex == cpuIndex else { return }
        cpuThinking = true

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run {
                executeCPUTurn()
            }
        }
    }

    private func checkCPUTurnAfterDelay() {
        // After player action, check if it's now CPU's turn
        if game.currentPlayerIndex == cpuIndex {
            scheduleCPUTurn()
        }
    }

    @MainActor
    private func executeCPUTurn() {
        cpuThinking = false
        guard game.currentPlayerIndex == cpuIndex else { return }

        switch game.phase {
        case .drawingCard:
            game.drawCard()
            updateCPUKnowledge()
            cpuAttackSequence()

        case .attackResult(.miss):
            game.acknowledgesMiss()
            updateCPUKnowledge()
            // Turn switches to player, nothing more to do

        case .choosingContinueOrStay:
            let shouldContinue = cpu.shouldContinueAttack(opponentCards: game.players[localIndex].cards)
            if shouldContinue {
                game.continueAttack()
                cpuAttackSequence()
            } else {
                game.stay()
                updateCPUKnowledge()
                // Turn switches to player
            }

        default:
            break
        }
    }

    private func cpuAttackSequence() {
        guard game.currentPlayerIndex == cpuIndex else { return }
        guard game.phase == .choosingTarget else { return }

        cpuThinking = true

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                cpuThinking = false
                performCPUAttack()
            }
        }
    }

    @MainActor
    private func performCPUAttack() {
        guard game.currentPlayerIndex == cpuIndex, game.phase == .choosingTarget else { return }

        let opponentCards = game.players[localIndex].cards
        guard let targetIndex = cpu.chooseTarget(opponentCards: opponentCards) else { return }

        game.selectTarget(index: targetIndex)

        let guess = cpu.guessCard(targetIndex: targetIndex, opponentCards: opponentCards)

        cpuThinking = true
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                cpuThinking = false
                game.message = "CPUは \(guess.color == .black ? "黒" : "白")\(guess.number) と推理しました！"
                game.attack(guessedNumber: guess.number, guessedColor: guess.color)
                updateCPUKnowledge()

                // Handle result after a delay
                Task {
                    try? await Task.sleep(for: .milliseconds(1000))
                    await MainActor.run {
                        handleCPUPostAttack()
                    }
                }
            }
        }
    }

    @MainActor
    private func handleCPUPostAttack() {
        guard game.currentPlayerIndex == cpuIndex else { return }

        switch game.phase {
        case .attackResult(.miss):
            cpuThinking = true
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run {
                    executeCPUTurn()
                }
            }

        case .choosingContinueOrStay:
            cpuThinking = true
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run {
                    executeCPUTurn()
                }
            }

        default:
            break
        }
    }

    // MARK: - Helpers

    private func targetHighlightIndex() -> Int? {
        if case .guessing(let idx) = game.phase, game.currentPlayerIndex == cpuIndex {
            // Show which card CPU is targeting
            return idx
        }
        if case .guessing(let idx) = game.phase, isMyTurn {
            return idx
        }
        return nil
    }
}
