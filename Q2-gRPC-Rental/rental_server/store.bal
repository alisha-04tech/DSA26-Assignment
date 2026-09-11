// ============================================================================
// store.bal  -  State + business rules for the Rental Accommodation System
//
// Contains NO gRPC types: no grpc:Error, no caller objects, no streams. Same
// split as Question 1 - the transport is an adapter, the rules live here.
// Both questions therefore share one architecture and only the adapter
// differs, which is the practical form of the Week 1 argument that middleware
// exists to mask heterogeneity.
//
// The message records (Property, UserProfile, Booking, ...) come from the
// GENERATED rental_pb.bal - we never hand-write them. That is the IDL payoff.
//
// Note: proto `double` maps to Ballerina `float`, not `decimal`.
// ============================================================================

import ballerina/time;

// ---------------------------------------------------------------------------
// TYPES THAT ARE *NOT* ON THE WIRE
// ---------------------------------------------------------------------------
// A cart item is server-side scratch state. It never leaves the process as a
// message, so it is a plain Ballerina record, not a protobuf message.
public type CartItem record {|
    string cartItemId;
    string guestId;
    string propertyId;
    string checkIn;
    string checkOut;
    int guests;
|};

public type NotFoundError distinct error;
public type ValidationError distinct error;
public type ConflictError distinct error;

// ---------------------------------------------------------------------------
// STATE
// ---------------------------------------------------------------------------
map<Property> propertyStore = {};
map<UserProfile> userStore = {};
map<CartItem[]> cartStore = {};                 // guest_id -> pending items
Booking[] bookingStore = [];                    // confirmed bookings
map<BookingConfirmation> replayCache = {};      // idempotency_key -> reply
int propertySeq = 0;
int bookingSeq = 0;
int cartSeq = 0;

// ---------------------------------------------------------------------------
// DATE HELPERS  (same algorithm as Q1)
// ---------------------------------------------------------------------------
function daysFromCivil(int y, int m, int d) returns int {
    int yy = m <= 2 ? y - 1 : y;
    int era = yy / 400;
    int yoe = yy - era * 400;
    int doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
    int doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}

public function toDayNumber(string dateStr) returns int|error {
    if dateStr.length() != 10 {
        return error ValidationError(string `Date must be YYYY-MM-DD, got '${dateStr}'`);
    }
    int y = check int:fromString(dateStr.substring(0, 4));
    int m = check int:fromString(dateStr.substring(5, 7));
    int d = check int:fromString(dateStr.substring(8, 10));
    if m < 1 || m > 12 || d < 1 || d > 31 {
        return error ValidationError(string `Date out of range: '${dateStr}'`);
    }
    return daysFromCivil(y, m, d);
}

function pad2(int v) returns string {
    return v < 10 ? string `0${v}` : v.toString();
}

public function nowIso() returns string {
    time:Civil c = time:utcToCivil(time:utcNow());
    // In this Ballerina release time:Civil declares hour/minute as required
    // int fields, so no nil-handling is needed.
    return string `${c.year}-${pad2(c.month)}-${pad2(c.day)}T${pad2(c.hour)}:${pad2(c.minute)}Z`;
}

// THE OVERLAP RULE.
// Intervals are HALF-OPEN: [checkIn, checkOut). The checkout day is free for
// the next guest, which is how real hotels work. Two stays clash iff
//     aIn < bOut  AND  bIn < aOut
// Back-to-back bookings (A checks out 14th, B checks in 14th) do NOT clash.
public function overlaps(int aIn, int aOut, int bIn, int bOut) returns boolean {
    return aIn < bOut && bIn < aOut;
}

function padId(int n) returns string {
    string s = n.toString();
    while s.length() < 4 {
        s = "0" + s;
    }
    return s;
}

// ---------------------------------------------------------------------------
// PROPERTIES
// ---------------------------------------------------------------------------

public function addProperty(AddPropertyRequest req) returns Property|error {
    if req.host_id.trim() == "" {
        return error ValidationError("host_id is required");
    }
    if req.name.trim() == "" {
        return error ValidationError("Property name is required");
    }
    if req.price_per_night <= 0.0 {
        return error ValidationError("price_per_night must be greater than zero");
    }
    if req.location.trim() == "" {
        return error ValidationError("location is required");
    }

    propertySeq += 1;
    string id = string `PROP-${padId(propertySeq)}`;

    Property p = {
        property_id: id,
        host_id: req.host_id,
        name: req.name,
        location: req.location,
        property_type: req.property_type,
        price_per_night: req.price_per_night,
        // An unset status arrives as *_UNSPECIFIED; default it to AVAILABLE.
        status: req.status == PROPERTY_STATUS_UNSPECIFIED ? AVAILABLE : req.status,
        max_guests: req.max_guests <= 0 ? 2 : req.max_guests,
        description: req.description
    };
    propertyStore[id] = p;
    return p;
}

public function getProperty(string propertyId) returns Property? {
    return propertyStore[propertyId];
}

// Sentinel-based partial update - see the design note in rental.proto.
public function updateProperty(UpdatePropertyRequest req) returns Property|error {
    Property? existing = propertyStore[req.property_id];
    if existing is () {
        return error NotFoundError(string `Property '${req.property_id}' not found`);
    }
    // OWNERSHIP CHECK: a host may only edit their own listing. Without this,
    // any client that guesses a property_id could reprice someone else's
    // house. Authorisation is a distributed-systems concern, not an
    // afterthought (Week 1: middleware and security).
    if existing.host_id != req.host_id {
        return error ConflictError(
            string `Host '${req.host_id}' does not own property '${req.property_id}'`);
    }
    if req.name.trim() != "" {
        existing.name = req.name;
    }
    if req.location.trim() != "" {
        existing.location = req.location;
    }
    if req.price_per_night > 0.0 {
        existing.price_per_night = req.price_per_night;
    }
    if req.status != PROPERTY_STATUS_UNSPECIFIED {
        existing.status = req.status;
    }
    if req.max_guests > 0 {
        existing.max_guests = req.max_guests;
    }
    if req.description.trim() != "" {
        existing.description = req.description;
    }
    return existing;
}

// Removing a listing returns the remaining AVAILABLE properties in the same
// region, as the brief specifies.
public function removeProperty(string propertyId, string hostId)
        returns [Property[], string]|error {
    Property? existing = propertyStore[propertyId];
    if existing is () {
        return error NotFoundError(string `Property '${propertyId}' not found`);
    }
    if existing.host_id != hostId {
        return error ConflictError(
            string `Host '${hostId}' does not own property '${propertyId}'`);
    }
    string region = existing.location;
    _ = propertyStore.remove(propertyId);

    // Any pending cart items pointing at the dead listing are now garbage -
    // drop them so a guest cannot confirm a booking for a property that no
    // longer exists.
    purgeCartItemsFor(propertyId);

    Property[] remaining = listAvailable({
        location: region,
        min_price: 0.0,
        max_price: 0.0,
        min_guests: 0,
        check_in: "",
        check_out: ""
    });
    return [remaining, region];
}

function purgeCartItemsFor(string propertyId) {
    foreach string guestId in cartStore.keys() {
        CartItem[] items = cartStore.get(guestId);
        CartItem[] kept = [];
        foreach CartItem it in items {
            if it.propertyId != propertyId {
                kept.push(it);
            }
        }
        cartStore[guestId] = kept;
    }
}

// The read model behind list_available_properties. Every filter optional;
// a zero / empty value means "no constraint".
public function listAvailable(ListAvailableRequest req) returns Property[] {
    int inDay = -1;
    int outDay = -1;
    if req.check_in != "" && req.check_out != "" {
        int|error i = toDayNumber(req.check_in);
        int|error o = toDayNumber(req.check_out);
        if i is int && o is int && o > i {
            inDay = i;
            outDay = o;
        }
    }

    Property[] result = [];
    foreach Property p in propertyStore {
        if p.status != AVAILABLE {
            continue;
        }
        if req.location.trim() != ""
            && p.location.toLowerAscii() != req.location.toLowerAscii() {
            continue;
        }
        if req.min_price > 0.0 && p.price_per_night < req.min_price {
            continue;
        }
        if req.max_price > 0.0 && p.price_per_night > req.max_price {
            continue;
        }
        if req.min_guests > 0 && p.max_guests < req.min_guests {
            continue;
        }
        result.push(p);
    }

    // If the guest supplied dates, also drop anything already booked then.
    if inDay >= 0 {
        Property[] free = [];
        foreach Property p in result {
            if !hasClash(p.property_id, inDay, outDay) {
                free.push(p);
            }
        }
        return free;
    }
    return result;
}

// Does this property already have a CONFIRMED booking clashing with the range?
public function hasClash(string propertyId, int inDay, int outDay) returns boolean {
    foreach Booking b in bookingStore {
        if b.property_id != propertyId {
            continue;
        }
        int|error bi = toDayNumber(b.check_in);
        int|error bo = toDayNumber(b.check_out);
        if bi is int && bo is int && overlaps(inDay, outDay, bi, bo) {
            return true;
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// USERS  (populated by the client-streaming RPC)
// ---------------------------------------------------------------------------
// Returns () on success, or a human-readable reason for rejection. We validate
// per record rather than aborting the whole stream: one bad profile must not
// discard the good ones.
public function addUser(UserProfile u) returns string? {
    if u.user_id.trim() == "" {
        return "user_id is required";
    }
    if u.name.trim() == "" {
        return string `user '${u.user_id}': name is required`;
    }
    if !u.email.includes("@") {
        return string `user '${u.user_id}': '${u.email}' is not a valid email`;
    }
    if u.role == USER_ROLE_UNSPECIFIED {
        return string `user '${u.user_id}': role must be HOST or GUEST`;
    }
    if userStore.hasKey(u.user_id) {
        return string `user '${u.user_id}': already registered`;
    }
    userStore[u.user_id] = u;
    return ();
}

public function userCount() returns int {
    return userStore.length();
}

// ---------------------------------------------------------------------------
// BOOKING CART  (book_property)
// ---------------------------------------------------------------------------
public function addToCart(BookPropertyRequest req) returns [CartItem, int, float]|error {
    if req.guest_id.trim() == "" {
        return error ValidationError("guest_id is required");
    }
    int inDay = check toDayNumber(req.check_in);
    int outDay = check toDayNumber(req.check_out);

    // The validation the brief explicitly asks for.
    if outDay <= inDay {
        return error ValidationError(
            string `check_out (${req.check_out}) must be after check_in (${req.check_in})`);
    }

    Property? p = getProperty(req.property_id);
    if p is () {
        return error NotFoundError(string `Property '${req.property_id}' not found`);
    }
    if p.status != AVAILABLE {
        return error ConflictError(
            string `Property '${req.property_id}' is not available (status ${p.status})`);
    }
    if req.guests > 0 && req.guests > p.max_guests {
        return error ValidationError(
            string `Property sleeps ${p.max_guests}, requested ${req.guests}`);
    }
    // Early clash check. ADVISORY only - the authoritative check runs again
    // inside confirm_booking, because another guest may confirm in between.
    // Checking twice is not redundant: it is the difference between a helpful
    // error now and a correct system later.
    if hasClash(req.property_id, inDay, outDay) {
        return error ConflictError(
            string `Property '${req.property_id}' is already booked for those dates`);
    }

    cartSeq += 1;
    string itemId = string `CART-${padId(cartSeq)}`;
    CartItem item = {
        cartItemId: itemId,
        guestId: req.guest_id,
        propertyId: req.property_id,
        checkIn: req.check_in,
        checkOut: req.check_out,
        guests: req.guests
    };
    CartItem[] existing = cartStore.hasKey(req.guest_id) ? cartStore.get(req.guest_id) : [];
    existing.push(item);
    cartStore[req.guest_id] = existing;

    int nights = outDay - inDay;
    float estimate = <float>nights * p.price_per_night;
    return [item, nights, estimate];
}

public function getCart(string guestId) returns CartItem[] {
    return cartStore.hasKey(guestId) ? cartStore.get(guestId) : [];
}

// ---------------------------------------------------------------------------
// CONFIRM  (confirm_booking)
// ---------------------------------------------------------------------------
// Look up a previous reply for this idempotency key. If we find one, the
// client is retrying a call we already completed - return the SAME answer
// instead of booking again. (Week 3: at-most-once via duplicate filtering.)
public function replayIfSeen(string key) returns BookingConfirmation? {
    if key.trim() == "" {
        return ();
    }
    return replayCache[key];
}

function remember(string key, BookingConfirmation reply) {
    if key.trim() == "" {
        return;
    }
    replayCache[key] = reply;
}

public function confirmBooking(string guestId, string cartItemId, string idempotencyKey)
        returns BookingConfirmation|error {

    CartItem[] cart = getCart(guestId);
    if cart.length() == 0 {
        return error NotFoundError(string `Guest '${guestId}' has an empty booking cart`);
    }

    // Either one specific item, or the whole cart.
    CartItem[] toConfirm = [];
    if cartItemId.trim() == "" {
        toConfirm = cart;
    } else {
        foreach CartItem it in cart {
            if it.cartItemId == cartItemId {
                toConfirm.push(it);
            }
        }
        if toConfirm.length() == 0 {
            return error NotFoundError(string `Cart item '${cartItemId}' not found`);
        }
    }

    Booking[] created = [];
    float grandTotal = 0.0;
    string stamp = nowIso();

    // Validate EVERYTHING before committing ANYTHING. If the second of three
    // items clashes we must not leave the first one booked - that would be a
    // torn, half-applied transaction. Build the full list first, commit last.
    foreach CartItem it in toConfirm {
        Property? p = getProperty(it.propertyId);
        if p is () {
            return error NotFoundError(
                string `Property '${it.propertyId}' no longer exists; cart item ${it.cartItemId} cannot be confirmed`);
        }
        if p.status != AVAILABLE {
            return error ConflictError(string `Property '${it.propertyId}' is now ${p.status}`);
        }
        int inDay = check toDayNumber(it.checkIn);
        int outDay = check toDayNumber(it.checkOut);

        // AUTHORITATIVE availability check.
        if hasClash(it.propertyId, inDay, outDay) {
            return error ConflictError(
                string `Property '${p.name}' was booked by someone else for ${it.checkIn} to ${it.checkOut}`);
        }
        // Also guard against two items in the SAME cart clashing with each other.
        foreach Booking b in created {
            if b.property_id == it.propertyId {
                int bi = check toDayNumber(b.check_in);
                int bo = check toDayNumber(b.check_out);
                if overlaps(inDay, outDay, bi, bo) {
                    return error ConflictError(
                        string `Two items in your own cart clash for property '${p.name}'`);
                }
            }
        }

        int nights = outDay - inDay;
        float total = <float>nights * p.price_per_night;
        grandTotal += total;

        bookingSeq += 1;
        created.push({
            booking_id: string `BK-${padId(bookingSeq)}`,
            guest_id: guestId,
            property_id: it.propertyId,
            property_name: p.name,
            check_in: it.checkIn,
            check_out: it.checkOut,
            nights: nights,
            price_per_night: p.price_per_night,
            total_cost: total,
            confirmed_at: stamp
        });
    }

    // COMMIT: persist the bookings and clear exactly what we confirmed.
    foreach Booking b in created {
        bookingStore.push(b);
    }
    clearCartItems(guestId, toConfirm);

    BookingConfirmation reply = {
        confirmed: true,
        bookings: created,
        total_cost: grandTotal,
        message: string `${created.length()} booking(s) confirmed. Total N$ ${grandTotal}.`,
        replayed: false
    };
    remember(idempotencyKey, reply);
    return reply;
}

function clearCartItems(string guestId, CartItem[] consumed) {
    CartItem[] items = cartStore.hasKey(guestId) ? cartStore.get(guestId) : [];
    CartItem[] kept = [];
    foreach CartItem it in items {
        boolean wasConsumed = false;
        foreach CartItem c in consumed {
            if c.cartItemId == it.cartItemId {
                wasConsumed = true;
                break;
            }
        }
        if !wasConsumed {
            kept.push(it);
        }
    }
    cartStore[guestId] = kept;
}

// ---------------------------------------------------------------------------
// SEED - Namibian listings so the demo has data immediately.
// ---------------------------------------------------------------------------
public function seed() {
    AddPropertyRequest[] samples = [
        {
            host_id: "H-001", name: "Dune Breeze Apartment", location: "Swakopmund",
            property_type: APARTMENT, price_per_night: 850.0, status: AVAILABLE,
            max_guests: 4, description: "Two-bedroom apartment two blocks from the beach."
        },
        {
            host_id: "H-001", name: "Desert Star Guest House", location: "Swakopmund",
            property_type: GUEST_HOUSE, price_per_night: 1200.0, status: AVAILABLE,
            max_guests: 6, description: "Quiet guest house with secure parking."
        },
        {
            host_id: "H-002", name: "Etosha Edge Lodge", location: "Outjo",
            property_type: LODGE, price_per_night: 2400.0, status: AVAILABLE,
            max_guests: 8, description: "Bush lodge 40km from Anderson Gate."
        },
        {
            host_id: "H-002", name: "Kalahari Campsite 7", location: "Mariental",
            property_type: CAMPSITE, price_per_night: 300.0, status: AVAILABLE,
            max_guests: 6, description: "Shaded campsite with ablutions."
        },
        {
            host_id: "H-003", name: "Windhoek City Loft", location: "Windhoek",
            property_type: APARTMENT, price_per_night: 950.0, status: MAINTENANCE,
            max_guests: 2, description: "Central loft - currently being renovated."
        }
    ];
    foreach AddPropertyRequest r in samples {
        // A wildcard `_` only binds values of type `any`, and `Property|error`
        // is not - errors are deliberately outside `any` so they can't be
        // silently discarded. Bind it properly and fail loudly if the
        // hard-coded seed data is ever wrong.
        Property|error added = addProperty(r);
        if added is error {
            panic added;
        }
    }

    UserProfile[] people = [
        {user_id: "H-001", name: "Maria Shikongo", email: "maria@example.na", role: HOST},
        {user_id: "H-002", name: "Johannes Amutenya", email: "johannes@example.na", role: HOST},
        {user_id: "H-003", name: "Selma Nghidinwa", email: "selma@example.na", role: HOST},
        {user_id: "G-001", name: "Tuli Haufiku", email: "tuli@example.na", role: GUEST}
    ];
    foreach UserProfile u in people {
        // addUser returns a rejection reason or nil. `string?` IS within
        // `any`, so a wildcard is legal here.
        string? _ = addUser(u);
    }
}
