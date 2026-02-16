import Foundation

@Observable
final class CPUPlayer: @unchecked Sendable {
    // Tracks which cards the CPU knows are eliminated (already seen/open)
    private var knownCards: Set<Int> = [] // sortValue based tracking

    // All possible card sort values: 0..23 (black0=0, white0=1, black1=2, white1=3, ...)
    private static let allSortValues = Set(0...23)

    func reset() {
        knownCards = []
    }

    func markKnown(card: Card) {
        knownCards.insert(card.sortValue)
    }

    func markKnownCards(from players: [Player]) {
        for player in players {
            for card in player.cards where card.isOpen {
                knownCards.insert(card.sortValue)
            }
        }
    }

    // MARK: - Choose which opponent card to attack

    func chooseTarget(opponentCards: [Card]) -> Int? {
        let closedIndices = opponentCards.enumerated().compactMap { index, card in
            card.isOpen ? nil : index
        }
        guard !closedIndices.isEmpty else { return nil }

        // Prefer cards where we can narrow down possibilities the most
        var bestIndex = closedIndices[0]
        var bestScore = Int.max

        for index in closedIndices {
            let candidates = possibleValues(for: index, in: opponentCards)
            if candidates.count < bestScore {
                bestScore = candidates.count
                bestIndex = index
            }
        }

        return bestIndex
    }

    // MARK: - Guess a number and color for a target card

    func guessCard(targetIndex: Int, opponentCards: [Card]) -> (number: Int, color: CardColor) {
        let candidates = possibleValues(for: targetIndex, in: opponentCards)

        if let pick = candidates.randomElement() {
            return sortValueToCard(pick)
        }

        // Fallback: random guess
        let number = Int.random(in: 0...11)
        let color: CardColor = Bool.random() ? .black : .white
        return (number, color)
    }

    // MARK: - Decide whether to continue attacking or stay

    func shouldContinueAttack(opponentCards: [Card]) -> Bool {
        let closedIndices = opponentCards.enumerated().compactMap { index, card in
            card.isOpen ? nil : index
        }
        guard !closedIndices.isEmpty else { return false }

        // Calculate best confidence
        for index in closedIndices {
            let candidates = possibleValues(for: index, in: opponentCards)
            if candidates.count == 1 {
                return true // We know exactly what it is, keep attacking
            }
        }

        // If few closed cards remain, be more aggressive
        if closedIndices.count <= 2 {
            let bestCount = closedIndices.map { possibleValues(for: $0, in: opponentCards).count }.min() ?? Int.max
            return bestCount <= 3
        }

        // Otherwise stay to be safe
        return false
    }

    // MARK: - Deduction Logic

    /// Returns possible sortValues for a card at a given index,
    /// considering the ordering constraint and known/eliminated cards.
    private func possibleValues(for index: Int, in cards: [Card]) -> [Int] {
        // Determine bounds from adjacent open cards
        var lowerBound = -1 // exclusive lower bound (sortValue)
        var upperBound = 24 // exclusive upper bound (sortValue)

        // Look left for the nearest known card
        for i in stride(from: index - 1, through: 0, by: -1) {
            if cards[i].isOpen {
                lowerBound = cards[i].sortValue
                break
            }
        }

        // Look right for the nearest known card
        for i in (index + 1)..<cards.count {
            if cards[i].isOpen {
                upperBound = cards[i].sortValue
                break
            }
        }

        // Count how many hidden cards are between lowerBound and this index
        // and between this index and upperBound, to further constrain
        let hiddenBefore = (0..<index).filter { !cards[$0].isOpen }.count
        let hiddenAfter = ((index + 1)..<cards.count).filter { !cards[$0].isOpen }.count

        let remaining = CPUPlayer.allSortValues.subtracting(knownCards)
        let inRange = remaining.filter { $0 > lowerBound && $0 < upperBound }

        // The card at this index must be the (hiddenBefore+1)-th smallest among
        // hidden values in range. We need at least (hiddenBefore + 1 + hiddenAfter) values.
        let sorted = inRange.sorted()
        guard sorted.count >= hiddenBefore + 1 + hiddenAfter else {
            return sorted // Not enough candidates, return all
        }

        // The card must be at position hiddenBefore..<(sorted.count - hiddenAfter)
        let start = hiddenBefore
        let end = sorted.count - hiddenAfter
        guard start < end else { return sorted }

        return Array(sorted[start..<end])
    }

    private func sortValueToCard(_ sortValue: Int) -> (number: Int, color: CardColor) {
        let number = sortValue / 2
        let color: CardColor = sortValue % 2 == 0 ? .black : .white
        return (number, color)
    }
}
