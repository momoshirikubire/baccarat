import Foundation
import MultipeerConnectivity

/// チップのテーブル。親の端末がテーブルを持ち、近くの端末（子）とは MultipeerConnectivity で直接つなぐ。
/// 子は「渡したい」を親に送り、親が確かめてから全員に新しいテーブルを配る。サーバーは使わない。
@Observable
final class ChipStore: NSObject {
    enum Role { case none, host, guest }

    enum Link: Equatable {
        case idle
        case joining
        case connected
    }

    struct FoundTable: Identifiable, Hashable {
        let peer: MCPeerID
        let name: String
        var id: MCPeerID { peer }
    }

    private(set) var role: Role = .none
    private(set) var table: ChipTable?
    /// 親だけが持つ参加用の4桁の番号
    private(set) var code = ""
    /// 親：近くの人が参加できる状態か
    private(set) var isOpen = false
    private(set) var connectedCount = 0
    private(set) var link: Link = .idle
    private(set) var found: [FoundTable] = []
    /// 親に断られたときなどの知らせ
    var notice: String?

    /// この端末の参加者ID。つなぎ直しても同じ人として残高が続く。
    let myID: UUID
    var myName: String

    @ObservationIgnored private var peerID: MCPeerID?
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private var hostPeer: MCPeerID?
    @ObservationIgnored private var pendingCode = ""
    /// 親：つながっている端末と参加者IDの対応
    @ObservationIgnored private var members: [MCPeerID: UUID] = [:]

    private static let serviceType = "keisen-chips"
    private static let file = "chips.json"

    private struct Saved: Codable {
        var table: ChipTable
        var code: String
    }

    override init() {
        let defaults = UserDefaults.standard
        if let s = defaults.string(forKey: "chipMemberID"), let id = UUID(uuidString: s) {
            myID = id
        } else {
            myID = UUID()
            defaults.set(myID.uuidString, forKey: "chipMemberID")
        }
        myName = defaults.string(forKey: "chipName") ?? ""
        super.init()
        if let saved = FileStore.load(Saved.self, from: Self.file) {
            role = .host
            table = saved.table
            code = saved.code
        }
    }

    // MARK: - 親

    func createTable(name: String, startingChips: Int, hostPlays: Bool, bankerCommission: Bool = false,
                     minBet: Int = 0, maxBet: Int = 0) {
        rememberName()
        stopBrowsing()
        var t = ChipTable(name: name, startingChips: max(0, startingChips), bankerCommission: bankerCommission,
                          minBet: max(0, minBet), maxBet: max(0, maxBet))
        if hostPlays {
            let trimmed = myName.trimmingCharacters(in: .whitespaces)
            t.join(id: myID, name: trimmed.isEmpty ? "記録係" : trimmed)
        }
        table = t
        code = String(format: "%04d", Int.random(in: 0...9999))
        role = .host
        save()
    }

    /// アプリを入れていない人のぶんも、親の端末で参加者として足せる
    func addLocalMember(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard role == .host, !trimmed.isEmpty else { return }
        table?.join(id: UUID(), name: trimmed)
        commit()
    }

    func removeMember(_ id: UUID) {
        guard role == .host, var t = table, t.member(id) != nil else { return }
        t.removeMember(id, by: myID)
        table = t
        commit()
    }

    /// ベットの下限・上限を変える（0 は「なし」）。いまのベットで外れるものは消す。
    func setLimits(minBet: Int, maxBet: Int) {
        guard role == .host, var t = table else { return }
        t.minBet = max(0, minBet)
        t.maxBet = max(0, maxBet)
        for (id, spots) in t.bets where t.limitProblem(spots) != nil { t.bets[id] = nil }
        table = t
        commit()
    }

    func restart() {
        guard role == .host else { return }
        table?.restart()
        commit()
    }

    func setOpen(_ open: Bool) {
        guard role == .host else { return }
        if open {
            let session = makeSession()
            let advertiser = MCNearbyServiceAdvertiser(
                peer: session.myPeerID,
                discoveryInfo: ["name": String((table?.name ?? "テーブル").prefix(40))],
                serviceType: Self.serviceType
            )
            advertiser.delegate = self
            advertiser.startAdvertisingPeer()
            self.advertiser = advertiser
        } else {
            advertiser?.stopAdvertisingPeer()
            advertiser = nil
            send(.closed)
            disconnect()
        }
        isOpen = open
    }

    func closeTable() {
        if isOpen { setOpen(false) }
        table = nil
        code = ""
        role = .none
        try? FileManager.default.removeItem(at: FileStore.url(Self.file))
    }

    // MARK: - 子

    func startBrowsing() {
        guard role == .none else { return }
        stopBrowsing()
        found = []
        let browser = MCNearbyServiceBrowser(peer: makePeerID(), serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    func join(_ found: FoundTable, code: String) {
        guard let browser else { return }
        rememberName()
        let session = makeSession()
        hostPeer = found.peer
        pendingCode = code
        role = .guest
        link = .joining
        let context = try? JSONEncoder().encode(Invitation(code: code))
        browser.invitePeer(found.peer, to: session, withContext: context, timeout: 20)
    }

    func leave(keepBrowsing: Bool = false) {
        if !keepBrowsing { stopBrowsing() }
        disconnect()
        hostPeer = nil
        table = nil
        role = .none
        link = .idle
    }

    // MARK: - だれでも

    /// 自分の画面からチップを動かす。親はそのまま、子は親に送って確かめてもらう。
    func move(from: ChipParty, to: ChipParty, amount: Int) {
        let move = ChipMove(from: from, to: to, amount: amount, by: myID)
        switch role {
        case .host:
            guard var t = table else { return }
            if let problem = t.problem(with: move) { notice = problem; return }
            t.apply(move)
            table = t
            commit()
        case .guest:
            if let problem = table?.problem(with: move) { notice = problem; return }
            send(.move(move))
        case .none:
            break
        }
    }

    /// バカラのベットを入れ直す。親は全員分、子は自分の分だけ（親に送って確かめてもらう）。
    func placeBet(_ spots: [BetSpot: Int], for id: UUID) {
        switch role {
        case .host:
            guard var t = table else { return }
            if let problem = t.problem(withBet: spots, for: id) { notice = problem; return }
            t.setBet(spots, for: id)
            table = t
            commit()
        case .guest:
            guard id == myID else { return }
            if let problem = table?.problem(withBet: spots, for: id) { notice = problem; return }
            send(.bet(member: id, spots: spots))
        case .none:
            break
        }
    }

    // MARK: - 親のバカラの罫線から

    /// 親が結果を記録したら精算して、罫線ごと全員に配る
    func handRecorded(_ shoe: Shoe) {
        let hands = shoe.hands
        guard role == .host, var t = table, let hand = hands.last else { return }
        t.settle(hand, handNumber: hands.count, shoeID: shoe.id, by: myID)
        t.hands = hands
        table = t
        commit()
    }

    /// 親が「1つ戻す」をしたら、その手の精算を取り消す（ベットは精算前に戻る）
    func handUndone(_ shoe: Shoe) {
        let hands = shoe.hands
        guard role == .host, var t = table else { return }
        t.undoRound(handNumber: hands.count + 1, shoeID: shoe.id)
        t.hands = hands
        table = t
        commit()
    }

    /// 新しいシューや、テーブルを作った直後に罫線をそろえる
    func syncHands(_ hands: [Hand]) {
        guard role == .host, var t = table, t.hands != hands else { return }
        t.hands = hands
        table = t
        commit()
    }

    var isMember: Bool { table?.member(myID) != nil }

    var displayName: String {
        let trimmed = myName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return role == .host ? "親" : "プレイヤー"
    }

    // MARK: - 内部

    private enum Message: Codable {
        case join(id: UUID, name: String)
        case move(ChipMove)
        case bet(member: UUID, spots: [BetSpot: Int])
        case state(ChipTable)
        case rejected(String)
        case closed
    }

    private struct Invitation: Codable {
        var code: String
    }

    private func rememberName() {
        UserDefaults.standard.set(myName, forKey: "chipName")
    }

    private func makePeerID() -> MCPeerID {
        // 探しているあいだは同じ ID を使う（名前を変えても、見つけた親への招待と食い違わないように）
        if let peerID, browser != nil || peerID.displayName == displayName { return peerID }
        // displayName は 63 バイトまで
        var name = displayName
        while name.utf8.count > 63 { name.removeLast() }
        let id = MCPeerID(displayName: name)
        peerID = id
        return id
    }

    private func makeSession() -> MCSession {
        disconnect()
        let session = MCSession(peer: makePeerID(), securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        return session
    }

    private func disconnect() {
        session?.disconnect()
        session = nil
        members = [:]
        connectedCount = 0
    }

    private func save() {
        guard role == .host, let table else { return }
        FileStore.save(Saved(table: table, code: code), to: Self.file)
    }

    /// 親：保存して、つながっている全員に配る
    private func commit() {
        save()
        if let table { send(.state(table)) }
    }

    private func send(_ message: Message, to peers: [MCPeerID]? = nil) {
        guard let session, let data = try? JSONEncoder().encode(message) else { return }
        let targets = peers ?? session.connectedPeers
        guard !targets.isEmpty else { return }
        try? session.send(data, toPeers: targets, with: .reliable)
    }

    private func handle(_ message: Message, from peer: MCPeerID) {
        switch (role, message) {
        case (.host, .join(let id, let name)):
            members[peer] = id
            table?.join(id: id, name: name)
            commit()
        case (.host, .move(let move)):
            guard var t = table, let id = members[peer] else { return }
            // 子が動かせるのは、自分のチップをほかの参加者へ渡すことだけ
            let allowed: Bool
            switch (move.from, move.to) {
            case (.member(let from), .member): allowed = from == id
            default: allowed = false
            }
            if !allowed || move.by != id {
                send(.rejected("この動かし方は親の端末からしかできません。"), to: [peer])
            } else if let problem = t.problem(with: move) {
                send(.rejected(problem), to: [peer])
            } else {
                t.apply(move)
                table = t
                commit()
            }
        case (.host, .bet(let member, let spots)):
            guard var t = table, let id = members[peer] else { return }
            if member != id {
                send(.rejected("ほかの人のベットは親の端末からしか入れられません。"), to: [peer])
            } else if let problem = t.problem(withBet: spots, for: id) {
                send(.rejected(problem), to: [peer])
            } else {
                t.setBet(spots, for: id)
                table = t
                commit()
            }
        case (.guest, .state(let t)):
            table = t
        case (.guest, .rejected(let reason)):
            notice = reason
        case (.guest, .closed):
            leave()
            notice = "テーブルを作った人がテーブルを閉じました。"
        default:
            break
        }
    }

    private func changed(_ peer: MCPeerID, to state: MCSessionState) {
        connectedCount = session?.connectedPeers.count ?? 0
        switch role {
        case .host:
            if state == .notConnected { members[peer] = nil }
        case .guest:
            guard peer == hostPeer else { return }
            switch state {
            case .connected:
                stopBrowsing()
                link = .connected
                send(.join(id: myID, name: displayName))
            case .notConnected:
                if link == .joining {
                    leave(keepBrowsing: true)
                    notice = "参加できませんでした。番号を確かめて、もう一度ためしてください。"
                } else {
                    leave()
                    notice = "テーブルを作った人の iPhone との接続が切れました。もう一度参加すると、残りのチップから続けられます。"
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        case .none:
            break
        }
    }
}

extension ChipStore: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, session === self.session else { return }
            self.changed(peerID, to: state)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(Message.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, session === self.session else { return }
            self.handle(message, from: peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension ChipStore: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let session = self.session,
                  let context, let invitation = try? JSONDecoder().decode(Invitation.self, from: context),
                  invitation.code == self.code
            else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, session)
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isOpen = false
            self?.notice = "近くの人とつなげませんでした。設定の「ローカルネットワーク」で罫線ノートを許可してください。"
        }
    }
}

extension ChipStore: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, browser === self.browser else { return }
            self.found.removeAll { $0.peer == peerID }
            self.found.append(FoundTable(peer: peerID, name: info?["name"] ?? peerID.displayName))
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.found.removeAll { $0.peer == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.notice = "近くのテーブルを探せませんでした。設定の「ローカルネットワーク」で罫線ノートを許可してください。"
        }
    }
}
