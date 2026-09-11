import ballerina/io;

configurable string serverUrl = "http://localhost:9091";

final RentalServiceClient ep = check new (serverUrl);

const string LINE = "----------------------------------------------------------------------";

function header(string t) {
    io:println("\n" + LINE);
    io:println("  " + t);
    io:println(LINE);
}

function ask(string p) returns string {
    return io:readln(p).trim();
}

function showProperty(Property p) {
    io:println(string `  ${p.property_id}  ${p.name}`);
    io:println(string `      ${p.location} | ${p.property_type} | N$ ${p.price_per_night}/night | sleeps ${p.max_guests} | ${p.status}`);
    if p.description != "" {
        io:println(string `      ${p.description}`);
    }
}

function parseType(string raw) returns PropertyType {
    match raw.toUpperAscii() {
        "HOUSE" => {
            return HOUSE;
        }
        "GUEST_HOUSE" => {
            return GUEST_HOUSE;
        }
        "LODGE" => {
            return LODGE;
        }
        "CAMPSITE" => {
            return CAMPSITE;
        }
    }
    return APARTMENT;
}

function parseStatus(string raw) returns PropertyStatus {
    match raw.toUpperAscii() {
        "AVAILABLE" => {
            return AVAILABLE;
        }
        "UNAVAILABLE" => {
            return UNAVAILABLE;
        }
        "MAINTENANCE" => {
            return MAINTENANCE;
        }
    }
    return PROPERTY_STATUS_UNSPECIFIED;
}

function addPropertyDemo() returns error? {
    header("ADD PROPERTY");
    string priceRaw = ask("  Price per night (NAD): ");
    string guestsRaw = ask("  Max guests: ");

    AddPropertyRequest req = {
        host_id: ask("  Host ID (e.g. H-001): "),
        name: ask("  Property name: "),
        location: ask("  Location / town: "),
        property_type: parseType(ask("  Type [APARTMENT|HOUSE|GUEST_HOUSE|LODGE|CAMPSITE]: ")),
        price_per_night: check float:fromString(priceRaw),
        status: AVAILABLE,
        max_guests: check int:fromString(guestsRaw),
        description: ask("  Description: ")
    };
    AddPropertyResponse resp = check ep->add_property(req);
    io:println(resp.success ? string `  OK - id = ${resp.property_id}` : "  REJECTED");
    io:println("  " + resp.message);
}

function createUsersDemo() returns error? {
    header("CREATE USERS  (client-side streaming)");

    UserProfile[] batch = [
        {user_id: "G-100", name: "Ndapewa Kaulinge", email: "ndapewa@example.na", role: GUEST},
        {user_id: "G-101", name: "Petrus Iileka", email: "petrus@example.na", role: GUEST},
        {user_id: "H-200", name: "Anna Nakale", email: "anna@example.na", role: HOST},
        {user_id: "G-102", name: "Bad Record", email: "not-an-email", role: GUEST},
        {user_id: "G-103", name: "Loide Amupolo", email: "loide@example.na", role: GUEST}
    ];

    io:println(string `  Pushing ${batch.length()} profiles down one stream...`);
    Create_usersStreamingClient streamingClient = check ep->create_users();

    foreach UserProfile u in batch {
        check streamingClient->sendUserProfile(u);
        io:println(string `    -> sent ${u.user_id} (${u.name})`);
    }
    // Half-close - the server replies only once the client is done sending.
    check streamingClient->complete();

    CreateUsersResponse? summary = check streamingClient->receiveCreateUsersResponse();
    if summary is CreateUsersResponse {
        io:println(string `  <- created ${summary.created_count}, rejected ${summary.rejected_count}`);
        foreach string e in summary.errors {
            io:println("     rejected: " + e);
        }
        io:println("  " + summary.message);
    }
}

function updatePropertyDemo() returns error? {
    header("UPDATE PROPERTY");
    io:println("  Blank / zero fields mean 'leave unchanged'.");
    string id = ask("  Property ID: ");
    string host = ask("  Your host ID: ");
    string priceRaw = ask("  New price per night (blank = unchanged): ");
    string statusRaw = ask("  New status [AVAILABLE|UNAVAILABLE|MAINTENANCE] (blank = unchanged): ");

    UpdatePropertyRequest req = {
        property_id: id,
        host_id: host,
        name: ask("  New name (blank = unchanged): "),
        location: "",
        price_per_night: priceRaw == "" ? 0.0 : check float:fromString(priceRaw),
        status: parseStatus(statusRaw),
        max_guests: 0,
        description: ""
    };
    PropertyResponse resp = check ep->update_property(req);
    io:println("  " + resp.message);
    if resp.success {
        showProperty(resp.property);
    }
}

function removePropertyDemo() returns error? {
    header("REMOVE PROPERTY");
    RemovePropertyRequest req = {
        property_id: ask("  Property ID to delete: "),
        host_id: ask("  Your host ID: ")
    };
    PropertyList resp = check ep->remove_property(req);
    io:println("  " + resp.message);
    if resp.count > 0 {
        io:println(string `  Still available in ${resp.region}: ${resp.count}`);
        foreach Property p in resp.properties {
            showProperty(p);
        }
    }
}

function listAvailableDemo() returns error? {
    header("LIST AVAILABLE PROPERTIES  (server-side streaming)");
    string loc = ask("  Location filter (blank = anywhere): ");
    string maxRaw = ask("  Max price per night (blank = no cap): ");
    string ci = ask("  Check-in  YYYY-MM-DD (blank = ignore dates): ");
    string co = ask("  Check-out YYYY-MM-DD (blank = ignore dates): ");

    ListAvailableRequest req = {
        location: loc,
        min_price: 0.0,
        max_price: maxRaw == "" ? 0.0 : check float:fromString(maxRaw),
        min_guests: 0,
        check_in: ci,
        check_out: co
    };

    stream<Property, error?> results = check ep->list_available_properties(req);
    int n = 0;
    check results.forEach(function(Property p) {
        n += 1;
        io:println(string `  [${n}]`);
        showProperty(p);
    });
    io:println(string `  End of stream. ${n} propert(ies).`);
}

function searchPropertyDemo() returns error? {
    header("SEARCH PROPERTY");
    SearchPropertyResponse resp = check ep->search_property({
        property_id: ask("  Property ID: ")
    });
    io:println("  Status: " + resp.status_message);
    if resp.found {
        showProperty(resp.property);
    }
}

function bookPropertyDemo() returns error? {
    header("BOOK PROPERTY  (adds to cart, commits nothing)");
    string guestsRaw = ask("  Number of guests: ");
    BookPropertyRequest req = {
        guest_id: ask("  Guest ID (e.g. G-001): "),
        property_id: ask("  Property ID: "),
        check_in: ask("  Check-in  YYYY-MM-DD: "),
        check_out: ask("  Check-out YYYY-MM-DD: "),
        guests: check int:fromString(guestsRaw)
    };
    BookPropertyResponse resp = check ep->book_property(req);
    if !resp.accepted {
        io:println("  REJECTED: " + resp.message);
        return;
    }
    io:println(string `  OK - cart item ${resp.cart_item_id}`);
    io:println(string `  ${resp.nights} night(s), estimated N$ ${resp.estimated_total}`);
}

function confirmBookingDemo() returns error? {
    header("CONFIRM BOOKING");
    string guest = ask("  Guest ID: ");
    string item = ask("  Cart item ID (blank = whole cart): ");
    string key = ask("  Idempotency key (reuse one to see duplicate filtering): ");

    BookingConfirmation resp = check ep->confirm_booking({
        guest_id: guest,
        cart_item_id: item,
        idempotency_key: key
    });

    if !resp.confirmed {
        io:println("  NOT CONFIRMED: " + resp.message);
        return;
    }
    if resp.replayed {
        io:println("  *** DUPLICATE - server replayed the original reply ***");
    }
    foreach Booking b in resp.bookings {
        io:println(string `  ${b.booking_id}  ${b.property_name}`);
        io:println(string `      ${b.check_in} -> ${b.check_out}  (${b.nights} nights x N$ ${b.price_per_night}) = N$ ${b.total_cost}`);
    }
    io:println(string `  TOTAL: N$ ${resp.total_cost}`);
}

// Runs every operation end to end with no input, for demo purposes.
function scriptedDemo() returns error? {
    header("SCRIPTED DEMO");

    io:println("\n[create_users] client-side streaming, 3 profiles, 1 invalid");
    Create_usersStreamingClient sc = check ep->create_users();
    UserProfile[] batch = [
        {user_id: "G-900", name: "Demo Guest", email: "demo@example.na", role: GUEST},
        {user_id: "H-900", name: "Demo Host", email: "host@example.na", role: HOST},
        {user_id: "G-901", name: "Broken", email: "no-at-sign", role: GUEST}
    ];
    foreach UserProfile u in batch {
        check sc->sendUserProfile(u);
    }
    check sc->complete();
    CreateUsersResponse? sum = check sc->receiveCreateUsersResponse();
    if sum is CreateUsersResponse {
        io:println(string `   created=${sum.created_count} rejected=${sum.rejected_count}`);
        foreach string e in sum.errors {
            io:println("   reason: " + e);
        }
    }

    io:println("\n[add_property]");
    AddPropertyResponse added = check ep->add_property({
        host_id: "H-900",
        name: "Demo Beach Cottage",
        location: "Henties Bay",
        property_type: HOUSE,
        price_per_night: 700.0,
        status: AVAILABLE,
        max_guests: 4,
        description: "Created by the scripted demo."
    });
    io:println(string `   -> ${added.property_id} : ${added.message}`);
    string demoId = added.property_id;

    io:println("\n[search_property]");
    SearchPropertyResponse found = check ep->search_property({property_id: demoId});
    io:println(string `   -> ${found.status_message}`);

    io:println("\n[update_property] drop the price to 650");
    PropertyResponse upd = check ep->update_property({
        property_id: demoId,
        host_id: "H-900",
        name: "",
        location: "",
        price_per_night: 650.0,
        status: PROPERTY_STATUS_UNSPECIFIED,
        max_guests: 0,
        description: ""
    });
    io:println(string `   -> ${upd.message} (now N$ ${upd.property.price_per_night})`);

    io:println("\n[update_property] wrong host - expect rejection");
    PropertyResponse denied = check ep->update_property({
        property_id: demoId,
        host_id: "H-999",
        name: "Hijacked",
        location: "",
        price_per_night: 1.0,
        status: PROPERTY_STATUS_UNSPECIFIED,
        max_guests: 0,
        description: ""
    });
    io:println(string `   -> success=${denied.success} : ${denied.message}`);

    io:println("\n[list_available_properties] server-side streaming");
    stream<Property, error?> st = check ep->list_available_properties({
        location: "",
        min_price: 0.0,
        max_price: 0.0,
        min_guests: 0,
        check_in: "",
        check_out: ""
    });
    int count = 0;
    check st.forEach(function(Property p) {
        count += 1;
        io:println(string `   [${count}] ${p.property_id} ${p.name} - N$ ${p.price_per_night}`);
    });
    io:println(string `   end of stream (${count} received)`);

    io:println("\n[book_property] 10-14 Oct");
    BookPropertyResponse b1 = check ep->book_property({
        guest_id: "G-900",
        property_id: demoId,
        check_in: "2026-10-10",
        check_out: "2026-10-14",
        guests: 2
    });
    io:println(string `   -> accepted=${b1.accepted} item=${b1.cart_item_id} nights=${b1.nights} est=N$ ${b1.estimated_total}`);

    io:println("\n[confirm_booking]");
    BookingConfirmation c1 = check ep->confirm_booking({
        guest_id: "G-900",
        cart_item_id: "",
        idempotency_key: "DEMO-KEY-1"
    });
    io:println(string `   -> confirmed=${c1.confirmed} total=N$ ${c1.total_cost} replayed=${c1.replayed}`);

    io:println("\n[confirm_booking] same key again - simulating a retry");
    BookingConfirmation c2 = check ep->confirm_booking({
        guest_id: "G-900",
        cart_item_id: "",
        idempotency_key: "DEMO-KEY-1"
    });
    io:println(string `   -> confirmed=${c2.confirmed} total=N$ ${c2.total_cost} replayed=${c2.replayed}`);

    io:println("\n[book_property] 12-16 Oct overlaps - expect rejection");
    BookPropertyResponse b2 = check ep->book_property({
        guest_id: "G-900",
        property_id: demoId,
        check_in: "2026-10-12",
        check_out: "2026-10-16",
        guests: 2
    });
    io:println(string `   -> accepted=${b2.accepted} : ${b2.message}`);

    io:println("\n[book_property] 14-17 Oct back-to-back - expect accept");
    BookPropertyResponse b3 = check ep->book_property({
        guest_id: "G-900",
        property_id: demoId,
        check_in: "2026-10-14",
        check_out: "2026-10-17",
        guests: 2
    });
    io:println(string `   -> accepted=${b3.accepted} : ${b3.message}`);

    io:println("\n[book_property] check-out before check-in - expect rejection");
    BookPropertyResponse b4 = check ep->book_property({
        guest_id: "G-900",
        property_id: demoId,
        check_in: "2026-11-10",
        check_out: "2026-11-05",
        guests: 2
    });
    io:println(string `   -> accepted=${b4.accepted} : ${b4.message}`);

    io:println("\n[remove_property] wrong host - expect rejection");
    PropertyList denied2 = check ep->remove_property({
        property_id: demoId,
        host_id: "H-999"
    });
    io:println(string `   -> ${denied2.message}`);

    io:println("\n[remove_property] correct host");
    PropertyList removed = check ep->remove_property({
        property_id: demoId,
        host_id: "H-900"
    });
    io:println(string `   -> ${removed.message}`);

    header("DEMO COMPLETE");
}

public function main() returns error? {
    io:println("Ministry of Tourism - Rental Accommodation System");
    io:println("Connected to " + serverUrl);

    while true {
        io:println("\n" + LINE);
        io:println("  1) add_property                (simple)");
        io:println("  2) create_users                (client streaming)");
        io:println("  3) update_property             (simple)");
        io:println("  4) remove_property             (simple)");
        io:println("  5) list_available_properties   (server streaming)");
        io:println("  6) search_property             (simple)");
        io:println("  7) book_property               (simple)");
        io:println("  8) confirm_booking             (simple)");
        io:println("  9) Run scripted demo");
        io:println("  0) Quit");

        string choice = ask("\n  Select: ");
        error? outcome = ();
        match choice {
            "1" => {
                outcome = addPropertyDemo();
            }
            "2" => {
                outcome = createUsersDemo();
            }
            "3" => {
                outcome = updatePropertyDemo();
            }
            "4" => {
                outcome = removePropertyDemo();
            }
            "5" => {
                outcome = listAvailableDemo();
            }
            "6" => {
                outcome = searchPropertyDemo();
            }
            "7" => {
                outcome = bookPropertyDemo();
            }
            "8" => {
                outcome = confirmBookingDemo();
            }
            "9" => {
                outcome = scriptedDemo();
            }
            "0" => {
                io:println("Goodbye.");
                return;
            }
            _ => {
                io:println("  Unknown option.");
            }
        }
        if outcome is error {
            io:println("  ! " + outcome.message());
        }
    }
}
