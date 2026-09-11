# Presentation defence notes — DSA612S Assignment 1

The brief says *"Groups will be required to present and defend their solution to receive marks"*
and the course outline says *"Assessment is based on conceptual understanding, not just implementation."*

The marks are in the **why**. Work through these out loud before you present.

---

## 1. Questions you will definitely be asked

### "Why a `table` instead of a `map` for the assets?"

A `map<Asset>` lets `POST /assets` silently overwrite an existing asset — that's
an update, not a create. `table<Asset> key(assetTag)` puts the key in the *type*:

- `.add()` fails loudly on a duplicate → we return 409 instead of destroying data
- `.hasKey()` and `[key]` are O(1), same as a map
- the compiler enforces that `assetTag` is `readonly`, so a key can never be
  mutated out from under the index

The brief said "Map or a table" — we can justify the choice, which is the point.

### "Why is `assetTag` marked `readonly`?"

Ballerina requires table key fields to be immutable. If you could reassign
`assetTag` after insertion, the table's internal index would point at the wrong
row. `readonly` turns that from a runtime bug into a compile error.

### "What's the difference between your 400, 404 and 409?"

- **400 Bad Request** — the message itself is malformed. `dueDate: "30-09-2026"`
  is day-month-year, not our format. Retrying identically will always fail.
- **404 Not Found** — well-formed request, the named resource doesn't exist.
- **409 Conflict** — well-formed request, resource exists, but it conflicts with
  current *state*. Loaning an already-loaned laptop. Might succeed later.

This drives client retry policy, which is why it matters. Our client's
`retryConfig` lists only 502/503/504 — transient server faults. We never
auto-retry a 4xx.

**Demo it:** `smoke-test.sh` has all three, and the loan endpoint produces all
three from one handler depending on what went wrong.

### "Why do the store functions return `distinct error` types?"

So the business layer never mentions HTTP. `store.bal` raises `NotFoundError`;
`service.bal` is the only file that knows that means 404. The alternative —
string-matching on error messages — breaks the moment someone rewrites a message.

We actually wrote it the bad way first (`if e.message().includes("not found")`)
and replaced it when the loan endpoint needed three distinct failure modes.
String matching doesn't scale past one.

### "Your two questions have the same architecture. Deliberate?"

Yes. Both are `store.bal` (rules, no transport types) + a transport adapter
(no business decisions). That's what lets the same booking logic sit behind
REST or gRPC. It's the practical form of the Week 1 argument that middleware
exists to mask heterogeneity.

Concrete proof: the same three error types drive HTTP status codes in Q1 and
response fields in Q2, with zero changes to either store.

---

## 2. gRPC / IDL questions

### "Why gRPC for Q2 and REST for Q1? What actually differs?"

| | REST (Q1) | gRPC (Q2) |
|---|---|---|
| Contract | none — hand-written both sides | `.proto`, machine-readable |
| Drift | silent, found at runtime | impossible, compile error |
| Encoding | JSON, text | Protocol Buffers, binary |
| Wire identity | field **names** | field **numbers** |
| Transport | HTTP/1.1 | HTTP/2, multiplexed |
| Streaming | no | client, server, bidirectional |

Point at `library_client/types.bal` — a hand-copied duplicate of the server's
model, with nothing stopping it drifting. Then `rental.proto` — one file
generates both sides. That contrast *is* the answer to "why does an IDL
matter", and we built it deliberately.

### "Why are field numbers never reused in your proto?"

Field numbers, not names, go on the wire. An old peer receiving an unknown
number skips it; one receiving a *recycled* number decodes the new field as the
old type and silently corrupts data. Never reusing a number is what makes
protobuf forwards- and backwards-compatible.

### "Why is `create_users` client-streaming rather than N unary calls?"

Cold start. Week 3 lists TCP/TLS connection establishment as a real cost.
Bulk-loading N profiles over one connection amortises that once instead of N
times. It's a batch import; one summary reply is the natural shape.

Note what our server does *not* do: abort on the first invalid record. In the
demo, 3 profiles go in, 1 has a bad email, and we return `created=2 rejected=1`
with the reason. Rejecting record 3 of 500 and discarding the other 497 would
be terrible. **Partial failure is normal in distributed systems.**

### "Why is `list_available_properties` server-streaming?"

Server memory stays flat regardless of result-set size, and the client renders
result 1 while the server still computes result N. Compare with one huge
response: latency to *first* result equals latency to the whole set.

### "You used sentinel values in `update_property` instead of proto3 `optional`. Why?"

Own this one, it's a real trade-off.

proto3 scalars have no "was this set?" — an unset string is `""`, an unset
double is `0`. Two fixes: (a) the `optional` keyword, adding explicit presence
tracking, or (b) treat `""`/`0`/`*_UNSPECIFIED` as "leave unchanged". We chose
(b) for portability across protobuf tool versions.

**The cost:** our API cannot express "set the description to empty string". Fine
for this domain. If pushed: `optional` is the better production choice and
switching is a one-line change per field.

---

## 3. The idempotency question — expect this one

### "What happens if `confirm_booking` times out and the client retries?"

Without protection: the server already committed, the reply was lost, the retry
commits a *second* booking. Guest is double-booked and double-charged.

Our fix is the `idempotency_key` field. It identifies the *intent*, not the
attempt. On arrival we check `replayCache`; if the key is present we return the
original confirmation with `replayed = true` and commit nothing.

**Demo it live** — option 9 sends the same key twice and prints
`replayed=true` with an identical N$2600 total.

### "Which call semantics does that give you?"

The transport gives **at-least-once** (retries can duplicate). The idempotency
key adds duplicate-request filtering, producing **at-most-once** business
behaviour — and since the retry also succeeds, the observable effect is
effectively exactly-once.

| | Retransmission | Duplicate filtering | Ours |
|---|---|---|---|
| Maybe | no | no | — |
| At-least-once | yes | no | what the network gives us |
| At-most-once | yes | yes | what the key adds |

### "Which of your operations are naturally idempotent?"

- **Safe & idempotent:** every `GET`, `search_property`, `list_available_properties`
- **Idempotent, not safe:** `PUT /assets/{tag}` (same patch twice = same state),
  `DELETE` (second one 404s but the *state* is identical), `update_property`
- **Not idempotent:** `POST /assets` (409 protects us), `book_property` (adds a
  cart item each time — deliberate, carts accumulate), `confirm_booking`
  (protected by the key)

---

## 4. Concurrency — know the weakness here

### "How does your server handle concurrent requests?"

**Be honest.** It doesn't, fully. The compiler emits HINTs: *"concurrent calls
will not be made to this method since the method is not an 'isolated' method."*
Ballerina serialises calls into our resource methods because our module-level
state isn't declared `isolated`.

That means we're **correct but not concurrent** — no data races, because
there's no parallelism to race. Requests queue.

**The fix**, which you should be able to describe: declare the state
`isolated`, wrap every access in a `lock` block, and `.clone()` values across
the lock boundary so a caller can't retain a reference into our state. Ballerina
then *proves* at compile time there's no data race — it refuses to build
otherwise.

**Why we didn't:** the isolation checker is strict and the refactor touches
every store function. With the deadline close we chose a working, verified
system over a half-migrated one. That's an engineering judgement, and saying so
is much stronger than pretending the HINTs aren't there.

### "Why check availability twice in the booking flow?"

`book_property` checks, and `confirm_booking` checks again. Not redundant —
between the two calls another guest may confirm the same dates. The first check
is *advisory* (helpful error early); the second is *authoritative*
(correctness). Classic check-then-act race.

### "What if item 2 of 3 in a cart clashes?"

Nothing is committed. We validate all items, build the full booking list, and
only then write. Otherwise you'd leave item 1 booked and item 2 failed — a
torn, half-applied transaction. Distributed systems have no free rollback; you
design so you don't need one.

---

## 5. The date logic

### "Explain your overlap rule."

Intervals are **half-open**: `[check_in, check_out)`. The checkout day is free
for the next guest, which is how hotels actually work. Two stays clash iff:

```
aIn < bOut  AND  bIn < aOut
```

**Demo:** 10–14 Oct booked; 12–16 Oct rejected (overlaps); 14–17 Oct accepted
(back-to-back).

### "Why not use a date library?"

Every date here is a plain calendar date with no timezone. Converting to a day
number and comparing integers avoids a whole class of timezone bugs. The
algorithm (days-from-civil) was verified against a reference calendar for every
date 2020→2032 — 4,748 dates, zero mismatches, including 2024-02-29 and the
2100/2000 century-leap-year edge cases.

---

## 6. Bugs we found and fixed — mention these unprompted

Finding your own bugs reads as engineering. Being caught by one reads as luck.

**1. Returned items stayed overdue forever.** Checking a room back in left the
booking schedule attached, so after its due date passed the overdue dashboard
would report a returned room as late — permanently. Fixed by clearing only
`LOAN` and `BOOKING` schedules on check-in, while leaving genuine `MAINTENANCE`
schedules intact.

**2. Loan returned 201 Created.** Ballerina defaults a `post` resource to 201
when you return a bare value. But loaning doesn't *create* anything — it changes
the state of something that already exists. 201 tells a client "a new thing
exists at some URL," which is a lie. Fixed by wrapping in `http:Ok`.

**3. Ballerina reserved words.** `conflict` is part of query-expression syntax
(`on conflict`), and `service` is a keyword — both broke compilation when used
as ordinary identifiers. Fixed by renaming, and by quoting where the name is
required: the brief's payload has a field literally called `type`, which we
declare as `'type` and which still serialises as `"type"` on the wire.

---

## 7. Two-minute opening

> Two services. Question 1 is a REST library system, Question 2 a gRPC rental
> platform.
>
> Both use the same architecture: a store layer holding the business rules with
> no transport types in it, and a thin adapter mapping those rules onto a wire
> protocol. That's why the same three error types become 400/404/409 over HTTP
> in Q1 and response fields in Q2 — the rules never changed, only the adapter.
>
> The contrast between the two was deliberate. In Q1 the client and server each
> hand-maintain a copy of the data model and can silently drift. In Q2 one
> `.proto` generates both sides, so drift is a compile error. That's the case
> for an IDL, and we built both to show it.
>
> The thing we'd point at first is `confirm_booking`. It's the unsafe operation
> — it takes money and blocks dates. We made it safely retryable with an
> idempotency key, so a client that times out and retries gets the original
> confirmation instead of a second booking. Let me demo that.

---

## 8. Self-test

Cover the answers. If you can't answer these, you can't defend the code.

1. Why does `POST /assets` return 409 rather than overwriting?
2. What does `readonly` on `assetTag` buy you?
3. Give a case where 409 is right and 400 is wrong.
4. What goes on the protobuf wire — names or numbers? Why does it matter?
5. Why is `create_users` client-streaming?
6. Two guests confirm the same dates simultaneously. What stops a double booking?
7. Guest A checks out 14 Oct, guest B checks in 14 Oct. Clash? Why not?
8. Your client times out on `confirm_booking` and retries. What happens?
9. What do the compiler HINTs about `isolated` actually mean for your server?
10. What's the single biggest weakness of your system?
