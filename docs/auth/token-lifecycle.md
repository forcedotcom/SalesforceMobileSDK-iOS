# Token Lifecycle: Code Exchange, Refresh, DPoP, and RTR

This document describes how the iOS SDK acquires and renews OAuth tokens, attaches DPoP proofs,
manages nonces, handles Refresh Token Rotation (RTR), and safely replays REST requests under
concurrency.

The primary classes are:

- **`SFOAuthCoordinator`** — drives interactive authentication and authorization-code exchange.
- **`SFSDKOAuth2`** — sends token-endpoint requests and handles DPoP nonce challenges.
- **`SFSDKTokenRefreshCoordinator`** — coalesces refresh requests per credential.
- **`SFOAuthSessionRefresher`** — builds a refresh request, updates credentials, and records RTR.
- **`SFRestRequest`** — builds an authenticated resource request with Bearer or DPoP headers.
- **`SFRestAPI`** — tracks request attempts, starts refresh, and replays active requests.
- **`DPoPRequestDecorator`**, **`DPoPProofBuilder`**, **`DPoPKeyStore`**, **`DPoPURL`**, and
  **`DPoPNonceCache`** — DPoP proof construction, key storage, URL canonicalization, and nonce
  caching.

---

## 1. Authorization Code Exchange

**Entry point:** `SFOAuthCoordinator.beginTokenEndpointFlow`

After browser authentication returns an authorization code, `SFOAuthCoordinator`:

1. Obtains an App Attestation assertion when attestation is enabled for the login domain.
2. Creates `SFSDKOAuthTokenEndpointRequest` with the client ID, redirect URI, server URL,
   credential identifier, token type, authorization code, PKCE verifier, and optional assertion.
3. Calls `SFSDKOAuth2.accessTokenForApprovalCode`.
4. `SFSDKOAuth2` builds `POST /services/oauth2/token` using the authorization-code grant.
5. If the credential is on the DPoP path, it adds a proof without `ath`, because no access token
   exists yet.
6. `sendTokenEndpointRequest` harvests `DPoP-Nonce` and retries exactly once when the server
   returns a nonce challenge.
7. On success, `SFOAuthCoordinator` updates `SFOAuthCredentials` with the access token, refresh
   token, instance URL, token type, and additional OAuth fields.

The credential identifier is established before token exchange. It is the stable scope for the
DPoP keypair, nonce cache, and later refresh coalescing.

---

## 2. Token Refresh

Refresh can be requested by multiple SDK components, including `SFRestAPI`,
`SFIdentityCoordinator`, and `SFUserAccountManager`. They all use the shared
`SFSDKTokenRefreshCoordinator`; callers should not construct an independent refresher.

### 2.1 Per-credential coordination

**Entry point:** `SFSDKTokenRefreshCoordinator.refreshSessionForCredentials`

The coordinator owns a serial queue and a dictionary keyed by `credentials.identifier`:

```text
activeRefreshes[credentials.identifier] = {
    refresher,
    completionBlocks[],
    errorBlocks[],
    backgroundTaskId
}
```

The first caller for a credential creates the entry and starts one `SFOAuthSessionRefresher`.
Later callers for that credential append their callbacks to the same entry. Refreshes for different
credential identifiers remain independent.

```text
Caller A                         Caller B, same credential
-------------------------------- --------------------------------
serial queue:
  no active entry
  create entry
  append A callbacks
  start refresher
                                 serial queue:
                                   find active entry
                                   append B callbacks
                                   return without another POST

token endpoint completes
serial queue:
  remove active entry
  end background task
main queue:
  notify A and B with one result
```

The coordinator serial queue protects only bookkeeping. It is not held during App Attestation or
network I/O. Completion and error callbacks are delivered on the main queue.

If iOS background time expires, the coordinator removes the active entry and delivers a
cancellation error to its waiters. A later network completion for that removed entry is ignored.

### 2.2 Refresh execution

`SFOAuthSessionRefresher` validates that the credentials contain an instance URL, client ID, and
refresh token. It then:

1. Obtains an App Attestation assertion when enabled.
2. Builds `SFSDKOAuthTokenEndpointRequest` from the current credentials.
3. Calls `SFSDKOAuth2.accessTokenForRefresh`.
4. Sends `grant_type=refresh_token` (or the configured hybrid refresh grant).
5. Attaches a DPoP proof and handles one token-endpoint nonce challenge when required.
6. Updates the shared `SFOAuthCredentials` object from the response.
7. Posts `kSFNotificationUserDidRefreshToken` on success.
8. Returns the updated credentials to the coordinator, which fans the result out to every waiter.

---

## 3. Refresh Token Rotation

With RTR, a successful refresh can return a new refresh token and invalidate the token used for
that exchange. Concurrent refresh POSTs with the same old token can therefore cause a successful
request to be followed by `invalid_grant` and logout.

`SFSDKTokenRefreshCoordinator` prevents that double spend by allowing at most one refresh request
per credential identifier. Unlike the Android winner/loser wait model, iOS stores callback arrays
on the in-flight entry and broadcasts the single result asynchronously.

On a successful response, `SFOAuthSessionRefresher` compares the updated refresh token with the
one used for the request. When it changed, the refresher:

- records `lastTokenRotationDate` on `SFOAuthCredentials`; and
- registers the `RT` app feature marker for the account.

If a refresh response omits `refresh_token`, `SFSDKOAuth2` carries the request's existing refresh
token into the parsed response. This preserves non-RTR sessions without making an omitted value
look like a rotation.

---

## 4. DPoP Proof Attachment

`SFRestRequest.prepareRequestForSend` delegates authentication headers to
`DPoPRequestDecorator.applyAuthHeaders` unless the caller already supplied `Authorization`.

```text
applyAuthHeaders(request, scope, accessToken, tokenType):
  if accessToken is empty -> leave request unchanged
  if isDPoPTokenType(tokenType):
    set Authorization to "DPoP <token>"
    load or create the credential-scoped EC P-256 keypair
    canonicalize the request URL for htu
    read a cached nonce for the URL and credential scope
    build a fresh proof with htm, htu, iat, jti, nonce, and ath
    set the DPoP header
  else:
    set Authorization to "Bearer <token>"
```

The four-argument overload used by `SFRestRequest` treats the credential's explicit `tokenType` as
authoritative and attaches a proof only when that value is DPoP. It does not consult the
process-wide DPoP preference.

The credential-object convenience overload uses `shouldAttachDPoP(scope:tokenType:)`. An explicit
token type is still authoritative, but when `tokenType` is nil during the `/authorize` to `/token`
transition, that overload can fall back to credential-scoped key material. This fallback also does
not consult the global preference. Token-endpoint proofs omit `ath`; resource proofs bind the proof
to the current access token with `ath`.

---

## 5. DPoP Nonce Lifecycle

`DPoPNonceCache` is a process-lifetime, thread-safe cache keyed by canonicalized `htu` and
credential scope. Reads are non-destructive. A scope-wide fallback lets a resource request reuse
the most recently observed token-endpoint nonce when no exact URL entry exists.

Salesforce normally seeds and rotates the nonce at the token endpoint. `SFSDKOAuth2` harvests the
response header before interpreting a token response and retries one nonce challenge with a newly
built proof.

`SFRestAPI` also defensively handles a resource-server HTTP 400 `use_dpop_nonce` response:

1. Confirm that the response belongs to the request's current data task.
2. Confirm that this request has not already used its one resource nonce retry.
3. Harvest `DPoP-Nonce` for the response URL and credential scope.
4. Rebuild and enqueue the request, producing a fresh proof.

This REST branch deliberately checks `statusCode == 400` and searches the response body directly
for `use_dpop_nonce`. It does not call `DPoPRequestDecorator.isNonceChallenge`, whose broader token
endpoint detection also recognizes a 401 carrying `DPoP-Nonce`.

Resource-server 401 responses do not take this inline nonce path. They enter normal access-token
refresh, where the token endpoint can provide a fresh nonce before the resource request is replayed.

Account deletion clears both the credential-scoped DPoP keypair and cached nonces. Credential
migration clears the old credential's DPoP state after the new credential state is established.

---

## 6. REST Refresh and Replay

An authenticated `SFRestAPI` instance maintains:

- `activeRequests`, containing requests that have not reached a terminal outcome;
- `refreshCycleActive`, coalescing expired-token responses within that API instance; and
- `SFRestRequest.sessionDataTask`, identifying the request's current network attempt.

When an attempt receives an authentication failure accepted by the retry policy:

1. The completion verifies that its data task is still current.
2. Under `@synchronized(self)`, `replayRequest` elects one refresh cycle for the API instance.
3. The API asks the shared `SFSDKTokenRefreshCoordinator` to refresh the credential.
4. Other failed requests remain in `activeRequests`; they do not start another refresh cycle.
5. On refresh success, `resendActiveRequestsRequiringAuthentication` snapshots the active set. It
   skips any newly admitted request whose initial task has not been published yet, and installs a
   successor for each request that already owns a task, with automatic auth retry disabled.
6. Each old task is cancelled after its successor is installed.
7. On refresh failure, the active set is atomically drained and each request receives one failure.

The local `refreshCycleActive` flag groups requests for one `SFRestAPI`. The shared refresh
coordinator is the cross-component, per-credential protection that prevents a second token POST.

---

## 7. Request-Attempt Ownership

Refresh coalescing alone does not make REST replay safe. An old task can finish while refresh is
installing its replacement. `SFRestAPI` therefore treats `request.sessionDataTask` as an ownership
token for one network attempt.

All compound ownership transitions use the same `@synchronized(self)` domain:

```text
terminal completion:
  lock
    require callbackTask == request.sessionDataTask
    request.sessionDataTask = nil
    remove request from activeRequests
    copy the attempt's callback block
  unlock
  invoke application or delegate code

authentication or DPoP retry:
  lock
    require callbackTask == request.sessionDataTask
    build, start, and publish the successor task
  unlock
```

There is an inexpensive current-task check before response parsing, followed by another check in
the terminal claim. The second check is essential: parsing runs outside the lock, so refresh could
replace the task between parsing and delivery.

The successor is created and assigned to `request.sessionDataTask` while holding the state lock.
`SFNetwork.sendRequest` resumes its task before returning, so the lock prevents an exceptionally
fast asynchronous completion from observing the request before task ownership is published.

Admission to `activeRequests` intentionally happens before initial request preparation, so a newly
submitted request can appear in a refresh replay snapshot while `sessionDataTask` is still nil.
Replay skips that entry: only the original sender may publish the first task, while replay may only
replace an existing task. This prevents replay and the original sender from independently creating
two initial attempts for the same request.

**Invariant:** `SFNetwork.sendRequest` must remain nonblocking and must not invoke its completion
synchronously. Changing that contract could introduce a lock-ordering or reentrancy hazard.

Application blocks and delegate methods always run after the state lock is released. The terminal
claim removes the completed request before client code runs. This also permits a callback to reuse
the same `SFRestRequest`: the new send re-adds the request and cannot be removed later by cleanup
belonging to the old attempt.

---

## 8. Cleanup and Failure Semantics

Normal success, network error, timeout, and terminal HTTP failure all use the terminal ownership
claim and can deliver at most one callback.

Logout cleanup and refresh-failure flushing follow an invalidate/drain/cancel/notify sequence:

1. Under the state lock, clear each current task, copy its failure block, drain `activeRequests`,
   and clear `refreshCycleActive`.
2. Release the lock.
3. Cancel the invalidated tasks.
4. Invoke the copied failure blocks.

Cancellation can enqueue a URL-session completion, but that completion sees that its task no longer
owns the request and is ignored. Calling client code outside the lock permits safe re-entry into
`SFRestAPI`.

On token-refresh failure, `SFRestAPI` preserves the established policy:

- `invalid_grant` triggers logout with `SFLogoutReasonTokenExpired`;
- `appAttestationFailed` triggers logout with `SFLogoutReasonAppAttestationFailed`; and
- `appAttestationFailedRetry` is reported without automatic logout.

---

## 9. End-to-End Scenarios

### 9.1 Successful authenticated request

```text
send request
  -> build Authorization and optional DPoP proof
  -> install current data task
  -> receive 2xx
  -> atomically claim terminal success
  -> invoke success callback outside the lock
```

### 9.2 Concurrent expired-token responses with RTR

```text
REST request A -> auth failure ----+     one token refresh POST
REST request B -> auth failure ----+---> SFSDKTokenRefreshCoordinator
identity request -> 401 -----------+     keyed by credentials.identifier
                                             |
                                             v
                                    rotated credentials published once
                                             |
                      +----------------------+----------------------+
                      v                      v                      v
                 replay A               replay B            retry identity
```

Each `SFRestAPI` still performs its own active-request replay, but every component observes the
same coordinated refresh result.

### 9.3 Resource-server nonce challenge

```text
task 1 -> HTTP 400 use_dpop_nonce + DPoP-Nonce
  -> verify task 1 is current
  -> harvest nonce and install task 2 under the ownership lock
  -> task 2 carries a fresh proof
  -> task 2 completes terminally
  -> any later task-1 completion is stale and ignored
```

### 9.4 Completion racing authentication replay

```text
old task passes the early stale check
old task parses outside the lock
refresh attempts to install a successor

Whichever acquires the ownership lock first wins:
  - terminal claim removes the request, so refresh cannot replay it; or
  - replay publishes the successor, so the old task fails its terminal recheck.
```

The request receives one terminal result in either ordering.

### 9.5 New request racing the replay snapshot

```text
new send adds request B to activeRequests
request B pauses before publishing its first task
refresh replay snapshots request B and sees sessionDataTask == nil
replay skips request B
the original send publishes B's first task
B's sole task claims and delivers its terminal callback
```

This is the admission-side counterpart to the completion race. Replay owns replacement of a
published attempt; it never creates the initial attempt on behalf of an in-progress sender.

---

## 10. Concurrency Invariants

1. At most one active coordinator entry exists per credential identifier; concurrent callers
   coalesce onto that entry.
2. A refresh network call never runs while the coordinator serial queue is synchronously held.
3. At most one data-task attempt can deliver a terminal result for an `SFRestRequest`.
4. Terminal completion and successor installation use the same request-state lock.
5. A successor task is published before its asynchronous completion can claim ownership.
6. DPoP and authentication retries remain nonterminal; they transfer ownership to a successor.
7. Application and delegate callbacks execute outside the request-state lock.
8. Cleanup invalidates request ownership before cancellation or client notification.
9. A replayed REST request cannot automatically start a second auth refresh cycle.
10. Refresh replay skips an active request with no published task; only its original sender may
    publish the first attempt.

The focused regression coverage lives in `SFRestAPIDataTaskRaceTests`, with coordinator behavior
covered by `SFSDKTokenRefreshCoordinatorTests` and token-endpoint nonce handling covered by the
`SFSDKOAuth2` test suites.
