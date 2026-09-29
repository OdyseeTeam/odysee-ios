# All very interesting stuff

But the actual data types returned from api.na-backend are around (https://github.com/lbryio/lbry.go/blob/cb83b2be3b3f2ddb3a725d3d386ce85742e5c2ad/extras/jsonrpc/daemon_types.go#L320)

`Python::StreamClaim``.value.stream_type` is likely https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/schema/claim.py#L208 rather than protobuf Type (https://github.com/lbryio/types/blob/73610f6654a62337c8edede48118e83bcb38aadf/v2/proto/claim.proto#L27)

## odysee-api

A proxy for jsonrpc calls to lbry-sdk (whether the Go or the Python seems irrelevant).

The one `resolve` method call used in odysee-api is for internal use, hence its data fields aren't complete. (lbry.go/extras/jsonrpc/daemon.go seems to be a Golang wrapper for the jsonrpc server; also won't trust its data types).

# lbryio/types

The source of truth (except where the jsonrpc server rewrites fields)

## odysee-frontend `Claim` type

Using this for the frontend `Claim` type as its fields are mostly non-optional and have been running fine in production. Will document differences from `lbry.go::Claim`. Note that this is analogous to Tx + `Output` from jsonrpc/protobuf (a "stake" in blockchain terms (https://spec.lbry.com/#conventions-and-terminology)).

The `Metadata` type (in the `Output.value` field) is `ClaimMeta` in the protobuf.

# Data flow

`jsonrpc_resolve -> Daemon.resolve -> Ledger.resolve -> Network.resolve (claimtrie) => Ledger._inflate_outputs -> Outputs.from_base64 => Ledger.request_transactions => Outputs.inflate -> Outputs.message_to_txo`

## `request_transactions` Returns Transactions to be the base of results

**Input**: `txs` (Derived from `tx_hash` of each `Output` of `Outputs`)
**Output**: FIXME

Network call at (https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/wallet/ledger.py#L858-L860) `blockchain.transaction.get_batch` (https://github.com/lbryio/herald.go/blob/d2193e980a88a50cc3c372e42791246ca33e2999/server/jsonrpc_blockchain.go#L822), which returns `TxHash` and `TxRaw`, the latter contains everything to be deserialized.

Loads `Output`s directly from Bitcoin data stream (https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/wallet/transaction.py#L752-L755)
`Output` is `amount: uint64` and `script: String`

Accessing getters on `Script`/`OutputScript` accesses `template`, which runs `parse` (https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/wallet/script.py#L314-L316)

## `message_to_txo` Takes a Protobuf message

(which???)

`meta::Type == 'error' -> error struct, censor = blocked channel`
(https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/schema/result.py#L115-L126)

Base is `tx`'s `output` (`outputs[nout]`), which is a `o-i Txo`

# Questions

(https://github.com/OdyseeTeam/lbry-sdk/blob/7080e2df69eb0312bb3e24e0c26939aaaeca0aef/lbry/schema/result.py#L101) does nothing?
