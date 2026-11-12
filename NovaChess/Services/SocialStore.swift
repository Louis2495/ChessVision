import Foundation
import Combine
import CloudKit
import GameKit

/// Public records require public-read / creator-write permissions in the CloudKit schema.
@MainActor final class SocialStore: ObservableObject {
    static let shared = SocialStore()
    private lazy var container = CKContainer(identifier: "iCloud.com.novachess.app")
    private var database: CKDatabase { container.publicCloudDatabase }
    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var accountReady = false
    @Published private(set) var busy = false
    @Published private(set) var results: [PlayerProfile] = []
    @Published private(set) var friends: [PlayerProfile] = []
    @Published private(set) var requests: [PlayerRequest] = []
    @Published private(set) var sent: Set<String> = []
    @Published private(set) var games: [PublicGame] = []
    @Published var error: String?
    private var ownerID = ""
    private var profileCache: [String: PlayerProfile] = [:]
    private func perform(_ operation: () async throws -> Void) async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        do { try await operation() } catch { self.error = error.localizedDescription }
    }
    private func optional(_ id: String, in db: CKDatabase? = nil) async throws -> CKRecord? {
        do { return try await (db ?? database).record(for: CKRecord.ID(recordName: id)) }
        catch let error as CKError where error.code == .unknownItem { return nil }
    }
    private func query(_ type: String, _ predicate: NSPredicate, limit: Int = 50) async throws -> [CKRecord] {
        let request = CKQuery(recordType: type, predicate: predicate)
        if type == "NCGame" { request.sortDescriptors = [NSSortDescriptor(key: "updated", ascending: false)] }
        if type == "NCProfile" { request.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)] }
        let result = try await database.records(matching: request, resultsLimit: limit)
        return try result.matchResults.map { try $0.1.get() }
    }
    private func decodeProfile(_ record: CKRecord) throws -> PlayerProfile {
        guard let name = record["username"] as? String, try Usernames.canonical(name) == name,
              record.recordID.recordName == "profile_" + name, let creator = record.creatorUserRecordID?.recordName else {
            throw ChessError.invalid("This player profile could not be verified.")
        }
        return PlayerProfile(username: name, ownerID: creator, gameCenterID: record["gameCenterID"] as? String ?? "")
    }
    private func player(_ username: String) async throws -> PlayerProfile {
        if let cached = profileCache[username] { return cached }
        guard let record = try await optional("profile_" + username) else { throw ChessError.invalid("This username no longer exists.") }
        let result = try decodeProfile(record); profileCache[username] = result; return result
    }
    func connect() async {
        await perform {
            guard try await container.accountStatus() == .available else { throw ChessError.invalid("Sign into iCloud in device Settings to use NovaChess players and spectating.") }
            ownerID = try await container.userRecordID().recordName; accountReady = true
            if let pointer = try await optional("myProfile", in: container.privateCloudDatabase), let username = pointer["username"] as? String {
                let existing = try await player(username)
                guard existing.ownerID == ownerID else { throw ChessError.invalid("The stored profile does not belong to this iCloud account.") }
                profile = existing
                try await updateGameCenterLink()
                try await loadContacts()
            }
        }
    }
    func register(_ input: String) async {
        await perform {
            guard accountReady, profile == nil else { throw ChessError.invalid("Connect to iCloud before choosing a username.") }
            let username = try Usernames.canonical(input)
            if let existing = try await optional("profile_" + username), existing.creatorUserRecordID?.recordName != ownerID { throw ChessError.invalid("That username is already taken.") }
            let record = try await optional("profile_" + username) ?? CKRecord(recordType: "NCProfile", recordID: CKRecord.ID(recordName: "profile_" + username))
            record["username"] = username as CKRecordValue
            record["gameCenterID"] = (GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.gamePlayerID : "") as CKRecordValue
            let saved = try await database.save(record)
            let pointer = try await optional("myProfile", in: container.privateCloudDatabase) ?? CKRecord(recordType: "NCAccount", recordID: CKRecord.ID(recordName: "myProfile"))
            pointer["username"] = username as CKRecordValue
            _ = try await container.privateCloudDatabase.save(pointer)
            profile = try decodeProfile(saved); profileCache[username] = profile
        }
    }
    private func updateGameCenterLink() async throws {
        guard GKLocalPlayer.local.isAuthenticated, let profile, profile.gameCenterID != GKLocalPlayer.local.gamePlayerID,
              let record = try await optional("profile_" + profile.username), record.creatorUserRecordID?.recordName == ownerID else { return }
        record["gameCenterID"] = GKLocalPlayer.local.gamePlayerID as CKRecordValue
        let saved = try await database.save(record)
        self.profile = try decodeProfile(saved); profileCache[profile.username] = self.profile
    }
    func search(_ input: String) async {
        await perform {
            guard accountReady, let prefix = Usernames.prefix(input) else { results = []; return }
            results = try await query("NCProfile", NSPredicate(format: "username BEGINSWITH %@", prefix), limit: 25).compactMap { try? decodeProfile($0) }
        }
    }
    private func verifiedRequest(_ record: CKRecord) async throws -> PlayerRequest {
        guard let from = record["sender"] as? String, let to = record["recipient"] as? String else { throw ChessError.invalid("Invalid friend request.") }
        let sender = try await player(from), recipient = try await player(to)
        guard sender.ownerID == record.creatorUserRecordID?.recordName, record["recipientOwner"] as? String == recipient.ownerID else { throw ChessError.invalid("Friend request ownership does not match its sender.") }
        return PlayerRequest(id: record.recordID.recordName, sender: sender, recipient: recipient)
    }
    func sendRequest(to user: PlayerProfile) async {
        await perform {
            guard let profile, profile.username != user.username, !sent.contains(user.username), !friends.contains(where: { $0.username == user.username }) else { return }
            let record = CKRecord(recordType: "NCFriendRequest")
            record["sender"] = profile.username as CKRecordValue; record["recipient"] = user.username as CKRecordValue
            record["recipientOwner"] = user.ownerID as CKRecordValue
            _ = try await database.save(record); sent.insert(user.username)
        }
    }
    func respond(_ request: PlayerRequest, accept: Bool) async {
        await perform {
            guard let profile, request.recipient.username == profile.username,
                  let source = try await optional(request.id) else { throw ChessError.invalid("This request is no longer available.") }
            let checked = try await verifiedRequest(source)
            guard checked.recipient.ownerID == ownerID else { throw ChessError.invalid("This request belongs to another player.") }
            let record = try await optional("response_" + request.id) ?? CKRecord(recordType: "NCFriendResponse", recordID: CKRecord.ID(recordName: "response_" + request.id))
            record["request"] = request.id as CKRecordValue
            record["sender"] = request.sender.username as CKRecordValue; record["recipient"] = profile.username as CKRecordValue
            record["accepted"] = NSNumber(value: accept)
            _ = try await database.save(record); try await loadContacts()
        }
    }
    func refreshContacts() async { await perform { try await updateGameCenterLink(); try await loadContacts() } }
    private func loadContacts() async throws {
        guard let profile else { return }
        profileCache = [profile.username: profile]
        let incoming = try await query("NCFriendRequest", NSPredicate(format: "recipient == %@", profile.username))
        let outgoing = try await query("NCFriendRequest", NSPredicate(format: "sender == %@", profile.username))
        let receivedReplies = try await query("NCFriendResponse", NSPredicate(format: "sender == %@", profile.username))
        let sentReplies = try await query("NCFriendResponse", NSPredicate(format: "recipient == %@", profile.username))
        var responses: Set<String> = [], connected: [String: PlayerProfile] = [:]
        for reply in receivedReplies + sentReplies {
            guard let requestID = reply["request"] as? String, let source = try await optional(requestID), let request = try? await verifiedRequest(source),
                  reply.creatorUserRecordID?.recordName == request.recipient.ownerID else { continue }
            responses.insert(requestID)
            if (reply["accepted"] as? NSNumber)?.boolValue == true {
                let other = request.sender.username == profile.username ? request.recipient : request.sender
                connected[other.username] = other
            }
        }
        var pending: [PlayerRequest] = []
        for record in incoming where !responses.contains(record.recordID.recordName) {
            if let valid = try? await verifiedRequest(record), valid.recipient.username == profile.username { pending.append(valid) }
        }
        requests = pending
        friends = connected.values.sorted { $0.username < $1.username }
        sent = Set(outgoing.compactMap { responses.contains($0.recordID.recordName) ? nil : $0["recipient"] as? String })
    }
    func profiles(forGameCenterIDs ids: [String]) async throws -> [PlayerProfile] {
        var profiles: [PlayerProfile] = []
        for id in ids {
            guard let record = try await query("NCProfile", NSPredicate(format: "gameCenterID == %@", id), limit: 1).first else { throw ChessError.invalid("Both players need linked NovaChess usernames before enabling spectators.") }
            profiles.append(try decodeProfile(record))
        }
        return profiles
    }
    func consent(gameID: String, allowed: Bool) async throws {
        guard let profile else { throw ChessError.invalid("Create a NovaChess username in Players first.") }
        let key = "consent_" + gameID + "_" + profile.username
        let record = try await optional(key) ?? CKRecord(recordType: "NCConsent", recordID: CKRecord.ID(recordName: key))
        record["username"] = profile.username as CKRecordValue; record["gameID"] = gameID as CKRecordValue; record["allowed"] = NSNumber(value: allowed)
        _ = try await database.save(record)
    }
    private func canSpectate(_ game: PublicGame) async throws -> Bool {
        for name in game.consentUsers {
            let profile = try await player(name)
            guard let record = try await optional("consent_" + game.gameID + "_" + name), record.creatorUserRecordID?.recordName == profile.ownerID,
                  (record["allowed"] as? NSNumber)?.boolValue == true else { return false }
        }
        return true
    }
    func publish(gameID: String, fen: String, notation: [String], mode: String, white: String, black: String, result: String?, consentUsers: [String] = []) async throws {
        guard let profile else { throw ChessError.invalid("Create a username in Players before sharing a public board.") }
        let key = "game_" + gameID + "_" + profile.username
        let value = PublicGame(id: key, gameID: gameID, publisher: profile.username, white: white, black: black, mode: mode, fen: fen, notation: notation, updated: Date(), result: result, consentUsers: consentUsers)
        guard try await canSpectate(value) else { try await unpublish(gameID: gameID); return }
        let record = try await optional(key) ?? CKRecord(recordType: "NCGame", recordID: CKRecord.ID(recordName: key))
        record["publisher"] = profile.username as CKRecordValue; record["gameID"] = gameID as CKRecordValue
        record["white"] = white as CKRecordValue; record["black"] = black as CKRecordValue; record["mode"] = mode as CKRecordValue
        record["fen"] = fen as CKRecordValue; record["notation"] = Array(notation.suffix(400)) as CKRecordValue
        record["result"] = (result ?? "") as CKRecordValue; record["consents"] = consentUsers as CKRecordValue
        record["listed"] = NSNumber(value: true); record["updated"] = Date() as CKRecordValue
        _ = try await database.save(record)
    }
    func unpublish(gameID: String) async throws {
        guard let profile else { return }
        let key = "game_" + gameID + "_" + profile.username
        if try await optional(key) != nil { _ = try await database.deleteRecord(withID: CKRecord.ID(recordName: key)) }
    }
    private func decodeGame(_ record: CKRecord) async throws -> PublicGame {
        guard let publisher = record["publisher"] as? String, let id = record["gameID"] as? String, let fen = record["fen"] as? String,
              record.creatorUserRecordID?.recordName == (try await player(publisher)).ownerID else { throw ChessError.invalid("Invalid public board.") }
        let game = PublicGame(id: record.recordID.recordName, gameID: id, publisher: publisher, white: record["white"] as? String ?? "White", black: record["black"] as? String ?? "Black", mode: record["mode"] as? String ?? "Chess", fen: fen, notation: record["notation"] as? [String] ?? [], updated: record.modificationDate ?? .distantPast, result: (record["result"] as? String).flatMap { $0.isEmpty ? nil : $0 }, consentUsers: record["consents"] as? [String] ?? [])
        _ = try game.board()
        guard try await canSpectate(game) else { throw ChessError.invalid("Spectating is no longer enabled for this game.") }
        return game
    }
    func browseGames(publisher: String? = nil) async {
        await perform {
            let predicate = publisher.map { NSPredicate(format: "publisher == %@ AND listed == 1", $0) } ?? NSPredicate(format: "listed == 1")
            let records = try await query("NCGame", predicate)
            var visible: [PublicGame] = []
            for record in records { if let game = try? await decodeGame(record) { visible.append(game) } }
            games = visible.sorted { $0.updated > $1.updated }
        }
    }
    func publicGame(_ id: String) async throws -> PublicGame {
        guard let record = try await optional(id) else { throw ChessError.invalid("This board is no longer public.") }
        return try await decodeGame(record)
    }
}
