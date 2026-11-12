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
| NCGame | publisher, gameID, white, black, mode, fen, result (String); notation (String list); listed (Int64); updated (Date/Time) | publisher + listed queryable; updated sortable |

Usernames are lowercase ASCII, 3–20 letters/numbers/underscores. The canonical username determines the public profile record ID, so competing creates cannot silently overwrite an existing name. A private account pointer restores the selected username on the same iCloud account. Game Center's app-scoped player ID is linked only from the currently authenticated local Game Center account. It is used for native invitations, not as a password or a claim of server-verified competitive identity.

Friend requests bind the recipient’s creator ID as well as their username, so a reused name cannot accept an older account’s request. Friend requests and responses carry usernames in public CloudKit routing records. They are not private messages. The app only shows requests for the signed-in profile, and treats a response as valid only when it belongs to the requested recipient. Accepted relationships appear under Friends. Searching supports username prefixes (2–20 characters), up to 25 results per request.

## Spectating

- Games publish automatically for players with a NovaChess username; there are no spectator consent controls or consent records. Correspondence publication uses linked player profiles for display names.
- Players → Watch public games shows read-only board snapshots and up to 400 SAN moves. Views refresh every five seconds while visible. Boards update when the playing device is active and connected; this is not a background broadcast service.
- Camera recordings and saved-game folders remain local and are not automatically published.

## Verification still required on Apple services

Create two profiles; race the same username and check only one succeeds; send/accept/decline a friend request; invite the accepted friend through Game Center; publish a bot game and observe another account's read-only updates; verify correspondence boards appear without approval; check profile ownership prevents another account from updating records. Repeat against the Production environment after schema deployment.
