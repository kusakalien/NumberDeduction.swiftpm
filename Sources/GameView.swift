import SwiftUI

struct GameView: View {
    let multiplayerService: MultiplayerService
    @State private var selectedNumber: Int = 0

    private var game: GameState? { multiplayerService.gameState }
    private var localIndex: Int { multiplayerService.localPlayerIndex }
    private var isMyTurn: Bool {
        guard let game else { return false }
        return game.currentPlayerIndex == localIndex
    }

    var body: some View {
        if let game {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Top: Opponent area
                    opponentArea(game: game)

                    Divider()

                    // Middle: Game info + controls
                    centerArea(game: game)

                    Divider()

                    // Bottom: Local player area
                    localPlayerArea(game: game)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
        } else {
            ProgressView("ゲームを準備中...")
        }
    }

    // MARK: - Opponent Area

    @ViewBuilder
    private func opponentArea(game: GameState) -> some View {
        let opponentIdx = 1 - localIndex
        VStack(spacing: 4) {
            PlayerHandView(
                player: game.players[opponentIdx],
                isLocalPlayer: false,
                highlightedIndex: targetHighlightIndex(for: opponentIdx, game: game),
                newlyInsertedCardId: insertedCardId(for: opponentIdx, game: game),
                onCardTap: isMyTurn && game.phase == .choosingTarget ? { index in
                    multiplayerService.sendSelectTarget(index: index)
                } : nil
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Center Area

    @ViewBuilder
    private func centerArea(game: GameState) -> some View {
        VStack(spacing: 12) {
            // Round & Score info
            HStack {
                Text("ラウンド \(game.currentRound)")
                    .font(.caption.bold())
                Spacer()
                Text("スコア: \(game.roundScores[0]) - \(game.roundScores[1])")
                    .font(.caption.bold())
            }
            .padding(.horizontal)

            // Message
            Text(game.message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(minHeight: 40)

            // Drawn card + Deck
            HStack(spacing: 24) {
                if let drawnCard = game.drawnCard, isMyTurn {
                    VStack(spacing: 4) {
                        Text("引いたカード")
                            .font(.caption2)
                        DrawnCardView(card: drawnCard, isFaceUp: true)
                    }
                } else if game.drawnCard != nil {
                    VStack(spacing: 4) {
                        Text("相手のカード")
                            .font(.caption2)
                        DrawnCardView(
                            card: game.drawnCard!,
                            isFaceUp: false
                        )
                    }
                }

                DeckView(remainingCards: game.deck.count) {
                    if isMyTurn && game.phase == .drawingCard {
                        multiplayerService.sendDrawCard()
                    }
                }
                .disabled(!isMyTurn || game.phase != .drawingCard)
            }

            // Action area
            actionArea(game: game)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Action Area

    @ViewBuilder
    private func actionArea(game: GameState) -> some View {
        switch game.phase {
        case .guessing:
            if isMyTurn {
                NumberPicker(
                    selectedNumber: $selectedNumber,
                    onConfirm: {
                        multiplayerService.sendAttack(number: selectedNumber)
                    }
                )
                .padding(.horizontal)
            } else {
                Text("相手が推理中...")
                    .foregroundStyle(.secondary)
            }

        case .attackResult(let result):
            if result == .miss {
                Button("確認") {
                    if isMyTurn {
                        multiplayerService.sendAcknowledgeMiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isMyTurn)
            }

        case .choosingContinueOrStay:
            if isMyTurn {
                HStack(spacing: 20) {
                    Button {
                        multiplayerService.sendContinueOrStay(continueAttack: true)
                    } label: {
                        Label("続けてアタック", systemImage: "flame.fill")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button {
                        multiplayerService.sendContinueOrStay(continueAttack: false)
                    } label: {
                        Label("ステイ", systemImage: "hand.raised.fill")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            } else {
                Text("相手が選択中...")
                    .foregroundStyle(.secondary)
            }

        case .roundOver(let winnerIndex):
            VStack(spacing: 12) {
                Text(winnerIndex == localIndex ? "ラウンド勝利！" : "ラウンド敗北...")
                    .font(.title2.bold())
                    .foregroundStyle(winnerIndex == localIndex ? .green : .red)

                Button("次のラウンドへ") {
                    multiplayerService.sendNextRound()
                }
                .buttonStyle(.borderedProminent)
            }

        case .gameOver(let winnerIndex):
            VStack(spacing: 12) {
                Text(winnerIndex == localIndex ? "勝利！🎉" : "敗北...")
                    .font(.largeTitle.bold())
                    .foregroundStyle(winnerIndex == localIndex ? .green : .red)

                Text("レーティングが更新されました")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("ロビーに戻る") {
                    multiplayerService.disconnect()
                }
                .buttonStyle(.borderedProminent)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Local Player Area

    @ViewBuilder
    private func localPlayerArea(game: GameState) -> some View {
        VStack(spacing: 4) {
            PlayerHandView(
                player: game.players[localIndex],
                isLocalPlayer: true,
                newlyInsertedCardId: insertedCardId(for: localIndex, game: game)
            )

            if !isMyTurn {
                Text("相手のターンです")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func targetHighlightIndex(for playerIdx: Int, game: GameState) -> Int? {
        if case .guessing(let idx) = game.phase, playerIdx != localIndex {
            return idx
        }
        return nil
    }

    private func insertedCardId(for playerIdx: Int, game: GameState) -> UUID? {
        guard let id = game.lastInsertedCardId else { return nil }
        return game.players[playerIdx].cards.contains(where: { $0.id == id }) ? id : nil
    }
}
