# NovaChess players and spectating

The player directory, friend requests and spectator boards use Apple's CloudKit public database. Game Center still transports two-player correspondence games and their replies. These services require the owner's Apple developer configuration; there is no bundled fake directory or app-owned web server.

## Apple setup

1. Create/enable the new app ID **com.novachess.app**, and a matching NovaChess App Store Connect record. Enable Game Center for it. This is a different app identity from the former app; old Game Center matches are not accessible to the new app ID.
2. In Xcode open **NovaChess.xcodeproj**, choose the NovaChess target and your paid development team. Enable Game Center and iCloud → CloudKit, using container **iCloud.com.novachess.app**. The project includes both capabilities and entitlements. If you use another container ID, change it in both `NovaChess.entitlements` and `SocialStore.swift`.
3. Open CloudKit Console and create the schema below in Development. Querying missing record types/indexes fails; deploying only the app code does not create a usable production directory.
4. Set the public types to allow authenticated users to Create, World/Authenticated users to Read, and only the record's Creator to Write. Do not give all authenticated users Write access. The client also verifies profile/request/response/publication creator IDs before using records. `NCAccount` is only saved in the private database and must not contain public data.
5. Deploy the schema/indexes and permissions to Production before distributing a production/TestFlight build. Test with two distinct iCloud and Game Center accounts on signed devices.

## Schema

| Record type | Fields | Query/sort indexes |
| --- | --- | --- |
| NCProfile | username (String), gameCenterID (String) | username queryable + sortable; gameCenterID queryable |
| NCAccount (private) | username (String) | fetched by fixed record ID `myProfile`; no query needed |
| NCFriendRequest | sender, recipient, recipientOwner (String) | sender + recipient queryable |
| NCFriendResponse | request, sender, recipient (String), accepted (Int64) | sender + recipient queryable |
| NCConsent | username, gameID (String), allowed (Int64) | fetched by deterministic record ID; no query needed |
| NCGame | publisher, gameID, white, black, mode, fen, result (String); notation, consents (String lists); listed (Int64); updated (Date/Time) | publisher + listed queryable; updated sortable |

Usernames are lowercase ASCII, 3–20 letters/numbers/underscores. The canonical username determines the public profile record ID, so competing creates cannot silently overwrite an existing name. A private account pointer restores the selected username on the same iCloud account. Game Center's app-scoped player ID is linked only from the currently authenticated local Game Center account. It is used for native invitations, not as a password or a claim of server-verified competitive identity.

Friend requests bind the recipient’s creator ID as well as their username, so a reused name cannot accept an older account’s request. Friend requests and responses carry usernames in public CloudKit routing records. They are not private messages. The app only shows requests for the signed-in profile, and treats a response as valid only when it belongs to the requested recipient. Accepted relationships appear under Friends. Searching supports username prefixes (2–20 characters), up to 25 results per request.

## Spectating

- Single-board bot games are private by default. In Play, expand **Spectators** and enable **Public board** after creating a username. The current board and up to 400 SAN moves are published. Disable it to remove your public record.
- Correspondence games require **both players** to have linked NovaChess profiles and enable **Allow spectators** on their own turns. Permission metadata is saved without consuming a move. Each participant has a creator-owned CloudKit consent record, and both are checked before publishing or displaying a board. Revoking a consent stops the in-app public view even if the other device has an older snapshot.
- Players → Watch public games lists opt-in boards. A player profile filters to that publisher. Spectator views are read-only and refresh every five seconds while visible. They never gain access to private Game Center match data or control the game.
- Public snapshots are intentionally public; stopping publication cannot remove copies someone already viewed. This is a casual social feature, not an anti-cheat or competitive game-verification service.

## Verification still required on Apple services

Create two profiles; race the same username and check only one succeeds; send/accept/decline a friend request; invite the accepted friend through Game Center; publish a bot game and observe another account's read-only updates; enable only one correspondence consent and verify it stays hidden, then enable both and revoke one; check profile ownership prevents another account from updating records. Repeat against the Production environment after schema deployment.
