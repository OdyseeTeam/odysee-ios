# Wallet Synchronization and Shared Preferences Wrapper

Defined in Odysee/Models/Wallet.swift

## Description

`Wallet` wraps and handles wallet sync (between internal-apis and Lbry data) as well as exposes shared preferences.

`SharedPreference` (Odysee/Models/SharedPreference.swift) defines the data types, Codable implementation, and mutators for shared preferences.\
Shared preferences are those stored under the `shared` key on Lbry `preference_get`/`preference_set` (which come from the user's wallet, stored on internal-apis).

## Architecture

`Wallet` is an `ObservableObject` class which holds only 1 public property, `prefs`, which is the current `SharedPreference` state.

In this context, "local" refers to the Lbry proxy (because it's acting as the user performing Lbry operations on their own device/app), and "remote" refers to internal-apis (which syncs the wallet across devices for the user, acting as a remote copy).

`remoteWalletHash` is stored in the instance, as it is used by internal-apis `sync/set` (`oldHash` parameter) to early return (with error) if the wallet hasn't changed.

### Singleton

It holds a [gate](https://github.com/mattmassicotte/TaskGate) to enforce one-at-a-time syncing and mutation to `prefs`. Due to this, `Wallet` is used as a **singleton**, with a private `init` and a static `shared` instance.

### Accessing `SharedPreference`

There are 3 ways to get the shared preferences managed by `Wallet`:

1. The static `Wallet.prefs` getter (managed by the `@Prefs` property wrapper) provides a read-only snapshot.
2. The static `Wallet.$prefs` property (managed by the `@Prefs` wrapper) provides a live (`AsyncSequence`) view to any property of `SharedPreference`.
3. SwiftUI views **MUST** observe the shared wallet (`@ObservedObject private var wallet = Wallet.shared`) and use the instance `prefs` property on that wallet. This is to ensure the view reacts to changes in shared preferences.

Mutating shared preferences can only be done via the static `Wallet.withSyncedPrefs*` wrappers (one can return a result from the mutator and is throwing).\
This wrapper ensures the `gate` is held and pulls/pushes sync. Mutation without this wrapper is impossible as `prefs` has a private setter.

### Synchronization

Two private methods are used for sync, one for pull and one for push. These **MUST** only be called when the `gate` is held.

This is the flow for a pull sync (updates the user's wallet on the Lbry proxy, and fetches the shared preferences):

> 1. Set `local hash` to the value from Lbry `sync_hash`.
> 2. Make an internal-apis `sync/get` call.
> 3. Update `remote hash` with that `hash`.
> 4. If local is out of sync (either the `changed` flag is set, or `local hash` $\neq$ `remote hash`), update local.
>    * Make a Lbry `sync_apply` call with `data` from `sync/get`.
> 
> If step 2 (`sync/get`) fails with a "404 Not Found", this means that there is no wallet data for the user (likely due to being a new sign up).
> In this case, the following flow is used after the failing step 2:
> 
> 1. Call Lbry `sync_apply`, to create a new wallet state.
> 2. Make an internal-apis `sync/set` call with the returned `data` and `hash`.
> 3. Update `remote hash` with the `hash` from `sync/set`.
> 
> After the pull succeeds, proceed to fetch or create `SharedPreference` (see the next section).

A push sync (push shared preferences to APIs, save wallet to internal-apis) is as follows:

> 1. Push `SharedPreference` (see the next section).
> 2. Call Lbry `sync_apply`, to fetch the latest state (after mutations made via Lbry `preference_set` and similar).
> 3. Make an internal-apis `sync/set` call with the returned `data` and `hash`, and `oldHash` set to `remote hash`.
> 4. If the `changed` flag is set, update `remote hash` with the `hash` from `sync/set`.

### Shared Preferences

The Lbry `preference_{g,s}et` methods can be used to get/set arbitrary preferences, but Odysee only uses the key `shared` to store a JSON blob of preferences.\
Its type definition can be found [in the web codebase](https://github.com/OdyseeTeam/odysee-frontend/blob/c605de2a2f461d61fcc4745dd1008510ef1e3737/ui/redux/actions/sync.ts#L560-L582), but the iOS parsing differs in two ways:

- It is more strict, in that some keys are non-optional (such as `following` and `blocked`).
- It doesn't decode some keys (not used in iOS), but still preserves them and keeps them intact on re-encoding.

To fetch/pull shared preferences, a Lbry `preference_get` call with `key = "shared"` is used, although there's some special handling in the iOS codebase, under the `BackendMethods.sharedPreferenceGet` method.\
If the `preference_get` call returns an error *other* than "authentication required" (implies the user *is* signed in, but has no shared preferences set), `nil` is specifically returned.\
The calling code should check for this, and initialise a `SharedPreference` with default values, followed by pushing these shared preferences.

To push shared preferences, a simple Lbry `preference_set` call with the preferences and `key = "shared"` will suffice.

#### Mutators and Predicates

`SharedPreference` extensions declare `mutating func`s and predicate computed `var`s/`func`s that can be used to interact with properties on the shared preferences.

These mutators and predicates don't need to take any care for synchronization, as they can only be called on mutable shared preferences, which only come from `Wallet.withSyncedPrefs*`.

Batch mutators MUST copy the property they are mutating and set it all at once, to only publish 1 update to observers. They MUST NOT use defer, so errors or early returns don't update the preference state.

#### Decoding and Encoding

There are a few special cases for encoding/decoding:

- All keys in `value` (the top level for data of the JSON blob) and `settings` are preserved, using the [`ValueCodable`](https://github.com/finestructure/ValueCodable) library. These are restored when encoding, before encoding the properties used by the app.
- `following` is received as an array of JSON objects, but stored as a dictionary of `LbryUri` to `"notifications disabled"`.
   * A property wrapper (`@SharedPreference.Following`) is used for this. The type it wraps (the dictionary) is named `SharedPreference.Follows`.
   * For encoding/decoding, the Coder **MUST** use with `_following` (the wrapper itself) directly, as the wrapper handles encoding/decoding into the internal format.
- `subscriptions` are not used within the app.
   * It is ignored when decoding.
   * An array is generated from the keys (`LbryUri`s) of `following` when encoding.
- `SharedPreference.CollectionGroup` keys are treated as optional (defaults are used on decoding), and set a piece of metadata (`origin`).
   * Because older versions of the iOS app didn't have support for playlists, earlier shared preference JSON blobs don't have these collection keys. A sane default (default builtin playlist, empty for other types of collections) is used if a key doesn't exist.
   * The app uses an internal metadata field named `origin` to track which group playlists came from (different behaviours/UI for builtin vs unpublished vs edited). A helper method `withOrigin` is used to set this field on all playlists in each group.
