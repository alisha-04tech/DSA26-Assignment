# DSA612S Assignment 1

Distributed Library & Resource Management System (REST) and Rental Accommodation System (gRPC).

**Due:** 14 September 2026, 23:59 · **Total:** 100 marks
Built with Ballerina 2201.12.8 (Swan Lake Update 12) on WSL2 / Ubuntu.

---

## Repository layout

```
.
├── Q1-REST-Library/
│   ├── library_service/          HTTP service, port 9090
│   │   ├── Ballerina.toml
│   │   ├── types.bal             data model + typed errors
│   │   ├── store.bal             table<Asset> key(assetTag) + business rules
│   │   └── service.bal           resource functions, error -> status mapping
│   ├── library_client/           CLI client
│   │   ├── Ballerina.toml
│   │   ├── types.bal
│   │   └── client.bal
│   └── smoke-test.sh             44 assertions, every endpoint + error path
│
└── Q2-gRPC-Rental/
    ├── rental.proto              THE CONTRACT - 15 of the 50 marks
    ├── rental_server/            gRPC server, port 9091
    │   ├── store.bal             state, dates, cart, idempotency cache
    │   ├── rentalservice_service.bal   the 8 remote functions
    │   └── rental_pb.bal         GENERATED - do not edit
    └── rental_client/
        ├── rentalservice_client.bal    menu + scripted demo
        └── rental_pb.bal         GENERATED - do not edit
```

---

## Running Question 1

Two terminals.

```bash
# terminal 1
cd Q1-REST-Library/library_service && bal run

# terminal 2
cd Q1-REST-Library/library_client && bal run
```

The service seeds 4 assets and 2 institutions on startup, including one
deliberately overdue schedule so the Overdue Dashboard has something to show.

### Testing

```bash
cd Q1-REST-Library && bash smoke-test.sh
```

**Current result: 44 passed, 0 failed.** Covers every endpoint plus 15 negative
cases (404s, 409s, 400s).

---

## Running Question 2

The generated stubs are not committed — they're derived from `rental.proto`,
and checking generated code into git is how contracts drift. Generate them:

```bash
cd Q2-gRPC-Rental
bal grpc --mode service --input rental.proto --output rental_server
bal grpc --mode client  --input rental.proto --output rental_client
```

That writes `rental_pb.bal` into each package. **Note:** `--mode service` also
writes an empty `*_service.bal` skeleton and `--mode client` writes a sample
`*_client.bal` — delete those, since our implementations replace them.

Then:

```bash
# terminal 1
cd Q2-gRPC-Rental/rental_server && bal run

# terminal 2
cd Q2-gRPC-Rental/rental_client && bal run
```

Pick **option 9** for a scripted run of all eight operations — both streaming
modes, the date-clash rejection, the back-to-back acceptance, and the
idempotent retry. That's the one to use in the presentation.

### Ports

| Service | Port |
|---|---|
| Q1 REST library service | 9090 |
| Q2 gRPC rental service | 9091 |

The gRPC generator defaults to 9090; we moved it to 9091 so both can run at
once, which the demo needs.

---

## Mark scheme mapping

### Question 1 (50)

| Deliverable | Marks | Where |
|---|---|---|
| Working solution, repo structure | 10 | Two clean packages per question, no generated code committed |
| Create/manage resources | 5 | `POST/GET/PUT/DELETE /library/assets[/{tag}]` |
| View all assets | 2 | `GET /library/assets` |
| View by institution and site | 3 | `GET /library/assets?institution=&site=` and `GET /library/institutions/{code}/assets` |
| Item status & booking schedules | 5 | `GET /assets/{tag}/schedules`, `POST /assets/{tag}/loan`, `POST /assets/{tag}/checkin` |
| Manage institutions | 5 | `GET/POST/PUT/DELETE /library/institutions[/{code}]` |
| Manage schedules | 3 | `POST/DELETE /assets/{tag}/schedules[/{id}]` |
| Error / wrong API call handling | 2 | Typed errors → 400/404/409 via one `mapError`, 15 negative tests |
| Database integration | 5 | `table<Asset> key(assetTag)` |
| Client implementation | 10 | 13-option CLI covering all five required capabilities |

Beyond the minimum: components, work orders with sub-tasks, overdue dashboard
with `daysOverdue`, referential integrity on institution delete, client-side
timeout and bounded retry.

### Question 2 (50)

| Deliverable | Marks | Where |
|---|---|---|
| Protocol Buffer definition | 15 | `rental.proto` — 8 RPCs, both streaming types |
| gRPC client | 10 | `rentalservice_client.bal` — all 8 invocable + scripted demo |
| gRPC server | 25 | `rental_server/` — persistence, date-overlap validation, cost calculation, idempotency |

---

## Verification performed

- **Q1:** 44/44 assertions passing in `smoke-test.sh`, covering every endpoint
  and every error path.
- **Q2:** scripted demo exercises all 8 RPCs. Verified by hand:
  - 10–14 Oct = 4 nights × N$650 = N$2600 (cost calculation)
  - retry with the same idempotency key returns `replayed=true` and the
    identical total — no double booking
  - 12–16 Oct rejected as overlapping; 14–17 Oct accepted as back-to-back
  - check-out before check-in rejected with a clear message
  - ownership checks reject `H-999` on both `update_property` and
    `remove_property`
- **Date arithmetic** (shared by both questions) was checked against a
  reference calendar for every date from 2020-01-01 to 2032-12-31 — 4,748
  dates, zero mismatches, including 2024-02-29, 2000-03-01 and 2100-03-01.

---

## Known limitations

Stated deliberately — see `PRESENTATION-DEFENCE.md` for the full discussion.

1. **State is in memory.** Restart and everything is gone. The brief asked for
   maps/tables, so this is in scope, but a production system needs a database
   and then replication and partitioning become live concerns.
2. **Single node, no replication.** Two processes talking is not fault
   tolerance. A real system survives losing a node; ours does not.
3. **Not `isolated`.** The compiler emits HINTs saying concurrent calls won't
   be made to our resource methods, because our state isn't declared
   `isolated` with `lock` blocks. Requests are therefore serialised rather
   than parallel. Correct, but not concurrent — see the defence notes for how
   we'd fix it and why we didn't.
4. **No authentication.** `update_property` checks that the caller *claims* to
   be the owning host, but nothing proves it. Production needs mTLS or JWTs.
5. **The idempotency cache grows forever.** Real systems expire keys after
   ~24 hours.
6. **Q1's client duplicates the server's data model** and can silently drift.
   That's the flaw Q2's IDL exists to fix — the contrast is deliberate.
