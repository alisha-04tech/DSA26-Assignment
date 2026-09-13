# rental_service — gRPC Server

 DSA612S — Distributed Systems and Applications
 Assignment 1, Question 2 — gRPC and Protocol Buffers


## What This Service Does

`rental_service` is the backend of a **Rental Accommodation Platform**,
built for the Ministry of Tourism. It manages two kinds of participants —
**Hosts**, who list and manage properties, and **Guests**, who search for
and book them — and exposes every operation as a **gRPC** service defined
by a shared contract (`rental.proto`), rather than a REST API.

Concretely, the service is responsible for:

- **Managing property listings** — creating, updating, removing, searching,
  and listing available accommodation.
- **Registering users in bulk** — accepting a stream of Host/Guest profiles
  in a single call, rather than one request per user.
- **Handling the booking lifecycle** — a two-step process where a Guest
  first places a booking in a temporary "cart" (validated for sane dates),
  then separately confirms it (validated against other confirmed bookings
  for date overlaps, with the total cost calculated automatically).

## Why gRPC Instead of REST (and Why It Matters Here)

Q1's `library_service` used REST because the operations were simple,
independent CRUD actions. This system is different in ways that make gRPC
a better fit, and understanding *why* is the point of this exercise:

- **A strict, typed contract.** Every message and method is defined once in
  `rental.proto`, and both the client and server generate their code from
  that exact same file. There is no way for the client to send a field the
  server doesn't expect, or vice versa — a whole category of REST's
  "trust the API docs are up to date" bugs simply cannot happen.
- **Streaming is a first-class concept.** `create_users` needs to accept
  many user profiles in one call, and `list_available_properties` needs to
  push back a variable-length list of properties one at a time. REST has no
  clean native way to express either of these — you'd have to fake it with
  batched JSON arrays or polling. gRPC handles both natively via
  **client-side streaming** and **server-side streaming**.
- **RPC — calling a remote function, not a URL.** Client code calls
  `rentalClient->add_property(request)` almost exactly like calling a local
  function. The networking (serialization, the HTTP/2 connection
  underneath, the wire format) is entirely hidden — the assignment is
  testing understanding of this abstraction specifically.

## How It's Built and How It Connects

- **Language/runtime:** Ballerina Swan Lake (Update 13+), using its
  `ballerina/grpc` module.
- **Contract-first workflow:** `rental.proto` lives at the project root
  (`Rental-System/rental.proto`), shared by both `rental_service` and
  `rental_client`. Ballerina's `bal grpc` tool (installed via
  `bal tool pull grpc`) reads it and generates `rental_pb.bal` in each
  project — containing the message `record` types, the client connector
  class, and supporting streaming helper classes. **`rental_pb.bal` is
  generated code and should never be hand-edited** — if the contract
  changes, regenerate it.
- **Transport:** gRPC over HTTP/2, listening on port `9090`. Unlike REST,
  there's no base path or per-resource URL — every method is addressed
  directly by name as defined in the `service RentalService { ... }` block
  of the contract.
- **Storage:** Three in-memory maps, matching the same deliberate,
  assignment-permitted approach used in Q1:
  - `map<Property> properties`, keyed by a server-generated `property_id`
    (format `PROP-<n>`, via an incrementing counter — necessary because,
    unlike Q1's client-supplied `assetTag`, gRPC requests here don't carry
    their own ID)
  - `map<Booking> bookings`, keyed by a server-generated `booking_id`
    (format `BOOK-<n>`) — `Booking` is a **server-internal type**, not part
    of `rental.proto`, since the contract only defines what crosses the
    network; the two-stage booking cart is purely a server-side concept
  - `map<User> users`, keyed by `user_id`, populated by `create_users`

## Data Model

```
Property (from rental.proto, keyed by property_id)
  property_id, name, location, property_type,
  price_per_night, status

Booking (server-internal only — not in rental.proto)
  booking_id, property_id, guest_name,
  check_in_date, check_out_date, confirmed

User (from rental.proto, keyed by user_id)
  user_id, name, role, email
```

> **Design note on `Booking`:** the brief describes a "temporary booking
> cart" without specifying its shape, so this type was designed to support
> exactly the two-step flow required: `confirmed: false` when first created
> by `book_property`, flipped to `true` only once `confirm_booking`
> succeeds. This is what lets `confirm_booking` correctly check for overlaps
> only against *other already-confirmed* bookings, rather than against every
> pending, possibly-abandoned booking attempt.

## API Reference (gRPC Methods)

All methods are defined in `rental.proto` under `service RentalService`.

| Method | RPC Type | Description |
|---|---|---|
| `add_property` | Simple | Host registers a new property. Server generates and returns `property_id`. |
| `update_property` | Simple | Host updates an existing property's full details, by `property_id`. Returns `404`-style not-found if the ID doesn't exist. |
| `remove_property` | Simple | Host deletes a property. Returns the full list of remaining properties. |
| `search_property` | Simple | Guest looks up one property by ID. Returns `found: false` gracefully if not present, rather than erroring. |
| `list_available_properties` | **Server-streaming** | Guest requests properties, optionally filtered by location and/or price range. Server streams back matching, `AVAILABLE` properties one at a time. |
| `book_property` | Simple | Guest requests to book a property for given dates. Validated (property exists, checkout after checkin) and added to a temporary, unconfirmed booking. |
| `confirm_booking` | Simple | Finalizes a pending booking — checked for date overlap against other confirmed bookings on the same property, cost calculated as `nights × price_per_night`, marked confirmed. |
| `create_users` | **Client-streaming** | Client streams multiple `User` profiles (Hosts or Guests) one at a time; server stores each and returns a single count/confirmation once the stream ends. |

## Error Handling & Validation

Rather than a `400`/`404`/`409` model (which is REST/HTTP-specific), each
method returns a response message with explicit `success`/`found` fields
and a human-readable `message`, since gRPC methods generally return one
typed value rather than distinct HTTP status codes:

| Situation | How it's handled |
|---|---|
| Searching for a `property_id` that doesn't exist | `search_property` returns `found: false, status_message: "Not Available"` |
| Updating/booking a `property_id` that doesn't exist | Returns `success: false` with an explanatory `message`, rather than throwing |
| Booking with `check_out_date <= check_in_date` | Rejected at `book_property` with `success: false` before ever reaching the cart |
| Confirming a booking that overlaps an existing **confirmed** booking on the same property | Rejected at `confirm_booking`, existing confirmed bookings are protected from double-booking |
| Confirming a `booking_id` that doesn't exist | Returns `success: false, message: "Booking not found"` |

## Running the Service

### Prerequisites

- [Ballerina Swan Lake](https://ballerina.io/downloads/) (Update 13 or later)
- The `grpc` Ballerina tool: `bal tool pull grpc` (one-time setup)

### Regenerating client code from the contract (if `rental.proto` changes)

```bash
cd rental_service
bal grpc --input ../rental.proto --output .
```

This regenerates `rental_pb.bal`. Do this any time the `.proto` file is
edited — the generated file must always match the current contract.

### Start the service

```bash
cd rental_service
bal run
```

The service starts listening on `localhost:9090`. **Ballerina does not
hot-reload** — any time server logic in `main.bal` is changed, the running
service must be stopped (Ctrl+C) and restarted with `bal run` again before
the change takes effect.

## Testing

Every method has been manually tested end-to-end using the companion
`rental_client` CLI (not just checked for successful compilation),
including a full realistic sequence: creating a property, searching for it,
updating its price, removing it, creating a second property, listing
available properties (server-streaming), booking it, confirming the
booking with a verified correct cost calculation, and streaming multiple
user profiles for bulk registration (client-streaming). See the project
build log for the full testing history and sample terminal output.
