import SwiftUI

// MARK: - Single Card View

struct CardView: View {
    let card: Card
    let isFaceUp: Bool
    let isHighlighted: Bool
    let isRevealed: Bool  // true when this card has been opened by opponent's attack
    let isNewlyInserted: Bool  // true when this card was just inserted (stay/miss)
    let onTap: (() -> Void)?

    init(card: Card, isFaceUp: Bool, isHighlighted: Bool = false, isRevealed: Bool = false, isNewlyInserted: Bool = false, onTap: (() -> Void)? = nil) {
        self.card = card
        self.isFaceUp = isFaceUp
        self.isHighlighted = isHighlighted
        self.isRevealed = isRevealed
        self.isNewlyInserted = isNewlyInserted
        self.onTap = onTap
    }

    private var cardBackground: Color {
        card.color == .black ? .black : .white
    }

    private var cardForeground: Color {
        card.color == .black ? .white : .black
    }

    private var borderColor: Color {
        if isNewlyInserted { return .orange }
        if isHighlighted { return .yellow }
        if isRevealed { return .red }
        return .gray
    }

    private var borderWidth: CGFloat {
        if isNewlyInserted { return 3 }
        if isHighlighted { return 3 }
        if isRevealed { return 2.5 }
        return 1
    }

    var body: some View {
        ZStack {
            // Background always shows the card color (black or white)
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: borderWidth)
                )

            if isFaceUp {
                // Face up — show number
                Text("\(card.number)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(isRevealed ? cardForeground.opacity(0.4) : cardForeground)
            } else {
                // Face down — show "?" to indicate hidden number
                Text("?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(cardForeground.opacity(0.4))
            }

            // Red overlay for revealed cards
            if isRevealed {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.15))
            }
        }
        .frame(width: 52, height: 76)
        .opacity(isRevealed ? 0.7 : 1.0)
        .shadow(color: isNewlyInserted ? .orange.opacity(0.6) : (isHighlighted ? .yellow.opacity(0.5) : .black.opacity(0.2)), radius: isNewlyInserted ? 8 : (isHighlighted ? 6 : 3))
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Drawn Card View

struct DrawnCardView: View {
    let card: Card
    let isFaceUp: Bool

    var body: some View {
        CardView(card: card, isFaceUp: isFaceUp)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.orange, lineWidth: 2)
            )
    }
}

// MARK: - Player Hand View

struct PlayerHandView: View {
    let player: Player
    let isLocalPlayer: Bool
    let highlightedIndex: Int?
    let newlyInsertedCardId: UUID?
    let onCardTap: ((Int) -> Void)?

    init(player: Player, isLocalPlayer: Bool, highlightedIndex: Int? = nil, newlyInsertedCardId: UUID? = nil, onCardTap: ((Int) -> Void)? = nil) {
        self.player = player
        self.isLocalPlayer = isLocalPlayer
        self.highlightedIndex = highlightedIndex
        self.newlyInsertedCardId = newlyInsertedCardId
        self.onCardTap = onCardTap
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(player.name)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(player.cards.enumerated()), id: \.element.id) { index, card in
                        CardView(
                            card: card,
                            isFaceUp: isLocalPlayer || card.isOpen,
                            isHighlighted: highlightedIndex == index,
                            isRevealed: isLocalPlayer && card.isOpen,
                            isNewlyInserted: card.id == newlyInsertedCardId,
                            onTap: {
                                onCardTap?(index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Number Picker (number only, color is always visible)

struct NumberPicker: View {
    @Binding var selectedNumber: Int
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("数字を推理してください")
                .font(.headline)

            // Number grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(0...11, id: \.self) { number in
                    Button {
                        selectedNumber = number
                    } label: {
                        Text("\(number)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(width: 44, height: 44)
                            .background(selectedNumber == number ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundStyle(selectedNumber == number ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: onConfirm) {
                Text("アタック！")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Deck View

struct DeckView: View {
    let remainingCards: Int
    let onDraw: () -> Void

    var body: some View {
        Button(action: onDraw) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 76)

                VStack(spacing: 2) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.title3)
                    Text("\(remainingCards)")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(remainingCards == 0)
        .opacity(remainingCards == 0 ? 0.5 : 1)
    }
}
