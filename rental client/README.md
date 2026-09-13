# rental_client — gRPC Command-Line Client

 DSA612S — Distributed Systems and Applications
 Assignment 1, Question 2 — gRPC and Protocol Buffers


## What This Client Does

`rental_client` is a Ballerina program that calls every method exposed by
`rental_service` over gRPC, demonstrating that the contract defined in
`rental.proto` produces a genuinely usable, working client — not just a
service that compiles in isolation. It exercises all three RPC shapes the
assignment requires: simple request/response, client-side streaming, and
server-side streaming.

Unlike `library_client` in Q1, which called a REST API with `http:Client`
and hand-built JSON payloads, this client calls the generated
`RentalServiceClient` class — code produced automatically from
`rental.proto`, guaranteeing the client can never disagree with the server
about what a method expects or returns.

## Why It Matters / Key Design Rationale

- **Proves the contract works both ways.** `rental_pb.bal` in this project
  is generated from the exact same `.proto` file as the server's — so a
  successful call here is direct proof the shared contract is internally
  consistent, not just that the server happens to run.
- **Demonstrates all three RPC shapes deliberately, not accidentally.** The
  client doesn't just call the easy simple-RPC methods — it explicitly
  exercises `create_users` (client-streaming: multiple `sendUser` calls
  followed by `complete()`) and `list_available_properties`
  (server-streaming: `.forEach()` over an incoming stream), since these are
  the parts of gRPC that don't exist in a REST-only mental model and are
  the main point of this deliverable.
- **Realistic operation sequencing.** The test flow mirrors how the system
  would actually be used: a property is created before it's searched,
  updated, or booked; a booking is placed in the cart before it's
  confirmed. IDs returned from earlier calls (`property_id`, `booking_id`)
  are threaded into later calls rather than hardcoded, proving state
  genuinely flows through the system correctly.

## How It's Built and How It Connects

- **Language/runtime:** Ballerina Swan Lake (Update 13+), using the
  generated `RentalServiceClient` class from `ballerina/grpc`.
- **Connection:** A single client is created once, pointed directly at the
  server's host and port — no base path, unlike REST:

  ```ballerina
  RentalServiceClient rentalClient = check new ("http://localhost:9090");
  ```

- **Requires the service to already be running**, in a **separate
  terminal**, before the client is started.
- **Generated code, not duplicated types:** `rental_pb.bal` is generated
  independently in this project (via `bal grpc --input ../rental.proto
  --output .`), from the same source contract as the server's copy. This is
  a meaningful contrast with Q1, where `types.bal` had to be manually kept
  identical by hand across both projects — here, regenerating from the
  contract removes that risk entirely.

## Calling Pattern by RPC Type

### Simple RPC (`add_property`, `update_property`, `remove_property`, `search_property`, `book_property`, `confirm_booking`)

One call, one typed response — closely mirrors calling a local function:

```ballerina
AddPropertyResponse response = check rentalClient->add_property(newProperty);
```

### Client-side streaming (`create_users`)

The client opens a stream, sends multiple messages one at a time, signals
completion, then receives a single response:

```ballerina
Create_usersStreamingClient userStream = check rentalClient->create_users();

check userStream->sendUser(user1);
check userStream->sendUser(user2);
check userStream->complete();

CreateUsersResponse? result = check userStream->receiveCreateUsersResponse();
```

### Server-side streaming (`list_available_properties`)

The client sends one request, then iterates over a stream of responses as
they arrive:

```ballerina
stream<Property, error?> propertyStream =
    check rentalClient->list_available_properties(listReq);

check propertyStream.forEach(function(Property p) {
    io:println(p.property_id, " | ", p.name);
});
```

## Test Sequence Implemented

| Step | Method called | What it proves |
|---|---|---|
| 1 | `add_property` | Property creation, server-generated ID |
| 2 | `search_property` | Lookup by ID returns correct stored data |
| 3 | `update_property` | Full-record update persists correctly |
| 4 | `remove_property` | Deletion works, remaining list reflects it |
| 5 | `add_property` (second property) | Fresh data exists to book |
| 6 | `list_available_properties` | **Server-streaming** — correct filtering, only `AVAILABLE` properties returned |
| 7 | `book_property` | Date validation, booking added to cart |
| 8 | `confirm_booking` | Overlap check passes, cost correctly calculated (`nights × price_per_night`) |
| 9 | `create_users` | **Client-streaming** — multiple users sent, single confirmation received with correct count |

## Running the Client

### Prerequisites

- [Ballerina Swan Lake](https://ballerina.io/downloads/) (Update 13 or later)
- `rental_service` must already be running (see its own `README.md`)
- The `grpc` Ballerina tool: `bal tool pull grpc` (one-time setup)

### Regenerating client code from the contract (if `rental.proto` changes)

```bash
cd rental_client
bal grpc --input ../rental.proto --output .
```

### Start the client

In a **separate terminal** from the service:

```bash
cd rental_client
bal run
```

Expected output includes property creation confirmations, the found
property's details, update/removal confirmations, the streamed list of
available properties, the booking and confirmation results (with total
cost), and the client-streaming user creation summary.

## Testing

Every RPC method has been manually tested end-to-end against a live,
running `rental_service` — not just checked for successful compilation.
This included verifying:

- Server-generated IDs increment correctly and persist across separate
  calls within the same server session (confirmed by observing sequential
  IDs like `PROP-1`, `PROP-2`).
- The date-overlap and cost-calculation logic in `confirm_booking` produces
  the mathematically correct total (verified: 3 nights at N$500/night
  correctly returned a total cost of 1500.0).
- `list_available_properties` correctly excludes a property that was
  previously removed, proving the server-streaming response reflects live,
  current data rather than a stale snapshot.
- `create_users` correctly reports the exact number of users sent through
  the stream.

See the project build log for the full testing history and sample terminal
output.
