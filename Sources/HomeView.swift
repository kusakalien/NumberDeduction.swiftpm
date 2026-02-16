import SwiftUI
import GameKit

struct HomeView: View {
    let multiplayerService: MultiplayerService

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Image(systemName: "suit.spade.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.indigo)

                    Text("Number Deduction")
                        .font(.largeTitle.bold())

                    Text("数字推理カードゲーム")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Player info
                if multiplayerService.isAuthenticated {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                            Text(multiplayerService.localPlayerName)
                                .font(.headline)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("レート: \(multiplayerService.localPlayerRating)")
                                .font(.subheadline.bold())
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    if multiplayerService.isAuthenticated {
                        Button {
                            multiplayerService.findMatch()
                        } label: {
                            Label("オンライン対戦", systemImage: "globe")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(multiplayerService.isMatchmaking)
                    } else {
                        Button {
                            multiplayerService.authenticate()
                        } label: {
                            Label("Game Centerにサインイン", systemImage: "gamecontroller.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding(.horizontal, 40)

                // Matchmaking indicator
                if multiplayerService.isMatchmaking {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("対戦相手を探しています...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("キャンセル") {
                            multiplayerService.cancelMatchmaking()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Error message
                if let error = multiplayerService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Rules button
                NavigationLink {
                    RulesView()
                } label: {
                    Label("遊び方", systemImage: "book.fill")
                        .font(.subheadline)
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Rules View

struct RulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ruleSection(
                    title: "カードについて",
                    icon: "rectangle.stack.fill",
                    content: """
                    白の0〜11までのカードと、黒の0〜11までのカード、合計24枚を使います。
                    """
                )

                ruleSection(
                    title: "並べ方",
                    icon: "arrow.left.arrow.right",
                    content: """
                    各プレイヤーは山札から4枚のカードを引き、左から小さい順に並べます。\
                    白と黒で同じ数字の場合は、黒を小さいとみなします。\
                    相手には裏向きで表示されます。
                    """
                )

                ruleSection(
                    title: "アタック",
                    icon: "flame.fill",
                    content: """
                    自分のターンに山札から1枚引き、相手のカードを1枚選んで数字と色を推理します。\n\
                    正解（イエス）→ 相手のカードがオープンされます。続けてアタックするか、ステイするか選べます。\n\
                    不正解（ノー）→ 引いたカードをオープンして自分の列に並べ、ターン交代です。
                    """
                )

                ruleSection(
                    title: "ステイ",
                    icon: "hand.raised.fill",
                    content: """
                    アタック成功後、続けずにステイを選ぶと、引いたカードを裏のまま自分の列に並べてターン交代します。
                    """
                )

                ruleSection(
                    title: "勝利条件",
                    icon: "trophy.fill",
                    content: """
                    相手のカードを全てオープンさせたら、そのラウンドの勝利です。\
                    2ラウンド連続で勝利したプレイヤーがゲームの勝者となります。\
                    各ラウンドごとに親（先攻）が交代します。
                    """
                )

                ruleSection(
                    title: "レーティング",
                    icon: "star.fill",
                    content: """
                    オンライン対戦ではEloレーティングシステムが適用されます。\
                    勝利するとレートが上がり、敗北すると下がります。
                    """
                )
            }
            .padding()
        }
        .navigationTitle("遊び方")
        .navigationBarTitleDisplayMode(.large)
    }

    private func ruleSection(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.indigo)

            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
