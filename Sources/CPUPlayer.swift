import Foundation

@Observable
final class CPUPlayer: @unchecked Sendable {
    // Tracks which card numbers are eliminated per color
    private var knownNumbers: [CardColor: Set<Int>] = [.black: [], .white: []]

    func reset() {
        knownNumbers = [.black: [], .white: []]
    }

    func markKnown(card: Card) {
        knownNumbers[card.color, default: []].insert(card.number)
    }

    func markKnownCards(from players: [Player]) {
        for player in players {
            for card in player.cards where card.isOpen {
                markKnown(card: card)
            }
        }
    }

    // MARK: - Choose which opponent card to attack

    func chooseTarget(opponentCards: [Card]) -> Int? {
        let closedIndices = opponentCards.enumerated().compactMap { index, card in
            card.isOpen ? nil : index
        }
        guard !closedIndices.isEmpty else { return nil }

        // Prefer cards where we can narrow down the number the most
        var bestIndex = closedIndices[0]
        var bestScore = Int.max

        for index in closedIndices {
            let candidates = possibleNumbers(for: index, in: opponentCards)
            if candidates.count < bestScore {
                bestScore = candidates.count
                bestIndex = index
            }
        }

        return bestIndex
    }

    // MARK: - Guess a number for a target card (color is already known)

    func guessNumber(targetIndex: Int, opponentCards: [Card]) -> Int {
        let candidates = possibleNumbers(for: targetIndex, in: opponentCards)

        if let pick = candidates.randomElement() {
            return pick
        }

        // Fallback
        return Int.random(in: 0...11)
    }

    // MARK: - Decide whether to continue attacking or stay

    func shouldContinueAttack(opponentCards: [Card]) -> Bool {
        let closedIndices = opponentCards.enumerated().compactMap { index, card in
            card.isOpen ? nil : index
        }
        guard !closedIndices.isEmpty else { return false }

        for index in closedIndices {
            let candidates = possibleNumbers(for: index, in: opponentCards)
            if candidates.count == 1 {
                return true
            }
        }

        if closedIndices.count <= 2 {
            let bestCount = closedIndices.map { possibleNumbers(for: $0, in: opponentCards).count }.min() ?? Int.max
            return bestCount <= 3
        }

        return false
    }

    // MARK: - Deduction Logic

    /// Returns possible numbers for a card at a given index.
    /// The color of each card is always visible, so we only need to deduce the number.
    /// Cards are sorted by sortValue (number * 2 + colorOffset), so ordering constrains possible numbers.
    private func possibleNumbers(for index: Int, in cards: [Card]) -> [Int] {
        let targetColor = cards[index].color

        // Determine sort value bounds from adjacent open cards
        var lowerBound = -1
        var upperBound = 24

        for i in stride(from: index - 1, through: 0, by: -1) {
            if cards[i].isOpen {
                lowerBound = cards[i].sortValue
                break
            }
        }

        for i in (index + 1)..<cards.count {
            if cards[i].isOpen {
                upperBound = cards[i].sortValue
                break
            }
        }

        // Count hidden cards before/after this index to further constrain position
        let hiddenBefore = (0..<index).filter { !cards[$0].isOpen }.count
        let hiddenAfter = ((index + 1)..<cards.count).filter { !cards[$0].isOpen }.count

        // Build set of remaining possible sort values (excluding known cards)
        let knownSortValues = buildKnownSortValues()
        let allSortValues = Set(0...23)
        let remaining = allSortValues.subtracting(knownSortValues)
        let inRange = remaining.filter { $0 > lowerBound && $0 < upperBound }

        let sorted = inRange.sorted()
        let totalNeeded = hiddenBefore + 1 + hiddenAfter
        guard sorted.count >= totalNeeded else {
            // Not enough candidates, return all matching the target color
            return sorted.compactMap { sv in
                let color: CardColor = sv % 2 == 0 ? .black : .white
                return color == targetColor ? sv / 2 : nil
            }
        }

        let start = hiddenBefore
        let end = sorted.count - hiddenAfter
        guard start < end else {
            return sorted.compactMap { sv in
                let color: CardColor = sv % 2 == 0 ? .black : .white
                return color == targetColor ? sv / 2 : nil
            }
        }

        // Filter to only numbers that match the target card's color
        let candidates = Array(sorted[start..<end])
        let numbers = candidates.compactMap { sv -> Int? in
            let color: CardColor = sv % 2 == 0 ? .black : .white
            return color == targetColor ? sv / 2 : nil
        }

        return numbers.isEmpty ? Array(0...11).filter { !knownNumbers[targetColor, default: []].contains($0) } : numbers
    }

    private func buildKnownSortValues() -> Set<Int> {
        var result = Set<Int>()
        for number in knownNumbers[.black, default: []] {
            result.insert(number * 2)
        }
        for number in knownNumbers[.white, default: []] {
            result.insert(number * 2 + 1)
        }
        return result
    }
}
