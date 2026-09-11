import ballerina/grpc;
import ballerina/log;

// 9091 rather than the generated default 9090, so this can run alongside the
// Q1 REST service.
listener grpc:Listener ep = new (9091);

@grpc:Descriptor {value: RENTAL_DESC}
service "RentalService" on ep {

    function init() {
        seed();
        log:printInfo("Rental gRPC service listening on 9091");
    }

    remote function add_property(AddPropertyRequest value) returns AddPropertyResponse|error {
        Property|error created = addProperty(value);
        if created is error {
            return {success: false, property_id: "", message: created.message()};
        }
        log:printInfo("Property registered", id = created.property_id, host = created.host_id);
        return {
            success: true,
            property_id: created.property_id,
            message: string `Property '${created.name}' registered in ${created.location}.`
        };
    }

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

    remote function remove_property(RemovePropertyRequest value) returns PropertyList|error {
        [Property[], string]|error outcome = removeProperty(value.property_id, value.host_id);
        if outcome is error {
            return {properties: [], region: "", count: 0, message: outcome.message()};
        }
        [Property[], string] [remaining, region] = outcome;
        return {
            properties: remaining,
            region: region,
            count: remaining.length(),
            message: string `Property '${value.property_id}' removed. ${remaining.length()} listing(s) still available in ${region}.`
        };
    }

    remote function search_property(SearchPropertyRequest value)
            returns SearchPropertyResponse|error {
        Property? found = getProperty(value.property_id);
        if found is () {
            return {found: false, available: false, status_message: "Not Found"};
        }
        boolean isFree = found.status == AVAILABLE;
        return {
            found: true,
            available: isFree,
            status_message: isFree ? "Available" : "Not Available",
            property: found
        };
    }

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

    remote function confirm_booking(ConfirmBookingRequest value)
            returns BookingConfirmation|error {
        // A repeated idempotency key means the client is retrying a call we
        // already completed, probably because our reply was lost. Return the
        // original confirmation rather than booking a second time.
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

    // Client-side streaming: drain the stream, then reply once. Invalid
    // records are counted and reported rather than aborting the batch.
    remote function create_users(stream<UserProfile, grpc:Error?> clientStream)
            returns CreateUsersResponse|error {
        int created = 0;
        int rejected = 0;
        string[] failures = [];

        record {|UserProfile value;|}|grpc:Error? entry = clientStream.next();
        while entry is record {|UserProfile value;|} {
            string? problem = addUser(entry.value);
            if problem is string {
                rejected += 1;
                failures.push(problem);
            } else {
                created += 1;
            }
            entry = clientStream.next();
        }
        // A grpc:Error here means the stream itself broke, which is different
        // from a record being invalid.
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

    // Server-side streaming: the runtime sends one message per element, so
    // memory stays flat regardless of result-set size.
    remote function list_available_properties(ListAvailableRequest value)
            returns stream<Property, error?>|error {
        Property[] matches = listAvailable(value);
        log:printInfo("Streaming available properties", count = matches.length(),
                      location = value.location);
        return matches.toStream();
    }
}
