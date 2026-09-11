// ============================================================================
// rentalservice_service.bal  -  gRPC transport adapter
//
// Nothing here makes a business decision. Each remote function unwraps the
// request, calls store.bal, and shapes the reply. This is the "server
// skeleton" role from the Week 3 slides made concrete: unmarshal -> invoke
// the real procedure -> marshal the reply.
//
// PORT NOTE: the generator defaults to 9090, which is where the Q1 HTTP
// service already listens. Moved to 9091 so both can run at once - which the
// demo needs, since the presentation shows REST and gRPC side by side.
//
// ERROR STRATEGY (worth defending):
// Business failures - "your price was zero", "that property is booked" - come
// back as a POPULATED RESPONSE with success=false and a message, not as a
// transport-level gRPC error. Rationale: those are normal, expected outcomes
// the client should render to the user, not exceptions. We reserve real
// errors for genuine transport faults. The alternative is mapping each onto a
// gRPC status (NOT_FOUND / INVALID_ARGUMENT / ABORTED) the way Q1 maps onto
// HTTP codes; that is equally valid, and the trade-off is that status codes
// are machine-readable for retry policies whereas a message field is not.
// ============================================================================

import ballerina/grpc;
import ballerina/log;

listener grpc:Listener ep = new (9091);

@grpc:Descriptor {value: RENTAL_DESC}
service "RentalService" on ep {

    function init() {
        seed();
        log:printInfo("Rental gRPC service listening on 9091");
    }

    // ======================================================================
    // 1. add_property  -  SIMPLE RPC
    // ======================================================================
    remote function add_property(AddPropertyRequest value) returns AddPropertyResponse|error {
        Property|error created = addProperty(value);
        if created is error {
            return {
                success: false,
                property_id: "",
                message: created.message()
            };
        }
        log:printInfo("Property registered", id = created.property_id, host = created.host_id);
        return {
            success: true,
            property_id: created.property_id,
            message: string `Property '${created.name}' registered in ${created.location}.`
        };
    }

    // ======================================================================
    // 3. update_property  -  SIMPLE RPC
    // ======================================================================
    remote function update_property(UpdatePropertyRequest value) returns PropertyResponse|error {
        Property|error updated = updateProperty(value);
        if updated is error {
            return {success: false, message: updated.message()};
        }
        return {
            success: true,
            message: string `Property '${updated.property_id}' updated.`,
            property: updated
        };
    }

    // ======================================================================
    // 4. remove_property  -  SIMPLE RPC
    // ======================================================================
    // Replies with the remaining available properties in that host's region,
    // exactly as the brief specifies.
    remote function remove_property(RemovePropertyRequest value) returns PropertyList|error {
        [Property[], string]|error outcome = removeProperty(value.property_id, value.host_id);
        if outcome is error {
            return {
                properties: [],
                region: "",
                count: 0,
                message: outcome.message()
            };
        }
        [Property[], string] [remaining, region] = outcome;
        return {
            properties: remaining,
            region: region,
            count: remaining.length(),
            message: string `Property '${value.property_id}' removed. ${remaining.length()} listing(s) still available in ${region}.`
        };
    }

    // ======================================================================
    // 6. search_property  -  SIMPLE RPC
    // ======================================================================
    remote function search_property(SearchPropertyRequest value)
            returns SearchPropertyResponse|error {
        Property? found = getProperty(value.property_id);
        if found is () {
            return {
                found: false,
                available: false,
                status_message: "Not Found"
            };
        }
        boolean isFree = found.status == AVAILABLE;
        return {
            found: true,
            available: isFree,
            status_message: isFree ? "Available" : "Not Available",
            property: found
        };
    }

    // ======================================================================
    // 7. book_property  -  SIMPLE RPC (adds to the cart, commits nothing)
    // ======================================================================
    remote function book_property(BookPropertyRequest value) returns BookPropertyResponse|error {
        [CartItem, int, float]|error outcome = addToCart(value);
        if outcome is error {
            return {
                accepted: false,
                cart_item_id: "",
                message: outcome.message(),
                nights: 0,
                estimated_total: 0.0
            };
        }
        [CartItem, int, float] [item, nights, estimate] = outcome;
        return {
            accepted: true,
            cart_item_id: item.cartItemId,
            message: string `Added to cart. ${nights} night(s), estimated N$ ${estimate}. Call confirm_booking to commit.`,
            nights: nights,
            estimated_total: estimate
        };
    }

    // ======================================================================
    // 8. confirm_booking  -  SIMPLE RPC (commits the cart)
    // ======================================================================
    // IDEMPOTENCY IN ACTION. Before doing any work we look for a cached reply
    // under the caller's idempotency_key. If we find one, this is a RETRY of a
    // call we already completed - the first reply was probably lost on the way
    // back. We return the original answer with replayed=true rather than
    // creating a second booking.
    //
    // This is how at-most-once semantics is built on top of an at-least-once
    // transport (Week 3, "RPC Call Semantics" + "The Importance of
    // Idempotency"). Without it, a client retry after a timeout would
    // double-book the guest and double-charge them.
    remote function confirm_booking(ConfirmBookingRequest value)
            returns BookingConfirmation|error {
        BookingConfirmation? replay = replayIfSeen(value.idempotency_key);
        if replay is BookingConfirmation {
            log:printInfo("Duplicate confirm_booking filtered", key = value.idempotency_key);
            BookingConfirmation copy = replay.clone();
            copy.replayed = true;
            copy.message = "Duplicate request detected - returning the original confirmation. " + copy.message;
            return copy;
        }

        BookingConfirmation|error result =
            confirmBooking(value.guest_id, value.cart_item_id, value.idempotency_key);
        if result is error {
            return {
                confirmed: false,
                bookings: [],
                total_cost: 0.0,
                message: result.message(),
                replayed: false
            };
        }
        log:printInfo("Booking confirmed", guest = value.guest_id, total = result.total_cost);
        return result;
    }

    // ======================================================================
    // 2. create_users  -  CLIENT-SIDE STREAMING
    // ======================================================================
    // The client sends N UserProfile messages then half-closes. We drain the
    // stream with next() until exhausted, then answer ONCE.
    //
    // Note we do NOT abort on the first bad record. Rejecting record 3 of 500
    // and discarding the other 497 would be terrible behaviour for a bulk
    // import; instead we count successes, collect reasons, and report both.
    remote function create_users(stream<UserProfile, grpc:Error?> clientStream)
            returns CreateUsersResponse|error {
        int created = 0;
        int rejected = 0;
        string[] failures = [];

        record {|UserProfile value;|}|grpc:Error? entry = clientStream.next();
        while entry is record {|UserProfile value;|} {
            UserProfile user = entry.value;
            string? problem = addUser(user);
            if problem is string {
                rejected += 1;
                failures.push(problem);
            } else {
                created += 1;
            }
            entry = clientStream.next();
        }
        // A non-nil grpc:Error here means the STREAM itself broke (a network
        // fault), which is different from a record being invalid.
        if entry is grpc:Error {
            log:printError("Client stream failed mid-flight", 'error = entry);
            return entry;
        }

        log:printInfo("Bulk user import finished", created = created, rejected = rejected);
        return {
            success: rejected == 0,
            created_count: created,
            rejected_count: rejected,
            errors: failures,
            message: string `${created} user(s) created, ${rejected} rejected. Registry now holds ${userCount()}.`
        };
    }

    // ======================================================================
    // 5. list_available_properties  -  SERVER-SIDE STREAMING
    // ======================================================================
    // We return a stream; the runtime pulls from it and writes one protobuf
    // message per element onto the same HTTP/2 connection. The client can
    // start rendering result 1 while the server is still producing result N -
    // that is the whole benefit over one fat response.
    remote function list_available_properties(ListAvailableRequest value)
            returns stream<Property, error?>|error {
        Property[] matches = listAvailable(value);
        log:printInfo("Streaming available properties", count = matches.length(),
                      location = value.location);
        return matches.toStream();
    }
}
