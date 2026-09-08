import ballerina/grpc;
import ballerina/time;
type Booking record {|
    string booking_id;
    string property_id;
    string guest_name;
    string check_in_date;
    string check_out_date;
    boolean confirmed;
|};
map<User> users = {};
map<Booking> bookings = {};
int bookingCounter = 0;

map<Property> properties = {};
int propertyCounter = 0;
listener grpc:Listener rentalListener = new (9090);

function daysBetween(string checkIn, string checkOut) returns int {
    time:Utc|time:Error inTime = time:utcFromString(checkIn + "T00:00:00.00Z");
    time:Utc|time:Error outTime = time:utcFromString(checkOut + "T00:00:00.00Z");
    if inTime is time:Utc && outTime is time:Utc {
        time:Seconds diff = time:utcDiffSeconds(outTime, inTime);
        return <int>(diff / 86400);
    }
    return 0;
}
@grpc:ServiceDescriptor {descriptor: RENTAL_DESC}
service "RentalService" on rentalListener {

    remote function add_property(AddPropertyRequest req) returns AddPropertyResponse|error {
        propertyCounter += 1;
        string newId = "PROP-" + propertyCounter.toString();

        Property newProperty = {
            property_id: newId,
            name: req.name,
            location: req.location,
            property_type: req.property_type,
            price_per_night: req.price_per_night,
            status: req.status
        };

        properties[newId] = newProperty;

        AddPropertyResponse response = {property_id: newId};
        return response;
    }
    remote function update_property(UpdatePropertyRequest req) returns UpdatePropertyResponse|error {
        if properties.hasKey(req.property_id) {
            Property updated = {
                property_id: req.property_id,
                name: req.name,
                location: req.location,
                property_type: req.property_type,
                price_per_night: req.price_per_night,
                status: req.status
            };
            properties[req.property_id] = updated;

            UpdatePropertyResponse response = {success: true, message: "Property updated successfully"};
            return response;
        } else {
            UpdatePropertyResponse response = {success: false, message: "Property not found"};
            return response;
        }
    }
   remote function remove_property(RemovePropertyRequest req) returns RemovePropertyResponse|error {
        if properties.hasKey(req.property_id) {
            _ = properties.remove(req.property_id);
        }

        Property[] remaining = properties.toArray();
        RemovePropertyResponse response = {remaining_properties: remaining};
        return response;
    }

    remote function search_property(SearchPropertyRequest req) returns SearchPropertyResponse|error {
        if properties.hasKey(req.property_id) {
            Property found = properties.get(req.property_id);
            SearchPropertyResponse response = {found: true, property: found, status_message: "Found"};
            return response;
        } else {
            SearchPropertyResponse response = {found: false, status_message: "Not Available"};
            return response;
        }
    }

   remote function book_property(BookPropertyRequest req) returns BookPropertyResponse|error {
        if !properties.hasKey(req.property_id) {
            BookPropertyResponse response = {success: false, booking_id: "", message: "Property not found"};
            return response;
        }

        if req.check_out_date <= req.check_in_date {
            BookPropertyResponse response = {success: false, booking_id: "", message: "Check-out date must be after check-in date"};
            return response;
        }

        bookingCounter += 1;
        string newBookingId = "BOOK-" + bookingCounter.toString();

        Booking newBooking = {
            booking_id: newBookingId,
            property_id: req.property_id,
            guest_name: req.guest_name,
            check_in_date: req.check_in_date,
            check_out_date: req.check_out_date,
            confirmed: false
        };
        bookings[newBookingId] = newBooking;

        BookPropertyResponse response = {success: true, booking_id: newBookingId, message: "Booking added to cart"};
        return response;
    }

    remote function confirm_booking(ConfirmBookingRequest req) returns ConfirmBookingResponse|error {
        if !bookings.hasKey(req.booking_id) {
            ConfirmBookingResponse response = {success: false, booking_id: "", total_cost: 0.0, message: "Booking not found"};
            return response;
        }

        Booking pending = bookings.get(req.booking_id);

        // Check for overlap against other CONFIRMED bookings on the same property
        foreach Booking existing in bookings {
            if existing.confirmed && existing.property_id == pending.property_id && existing.booking_id != pending.booking_id {
                boolean overlaps = pending.check_in_date < existing.check_out_date && pending.check_out_date > existing.check_in_date;
                if overlaps {
                    ConfirmBookingResponse response = {success: false, booking_id: req.booking_id, total_cost: 0.0, message: "Dates overlap with an existing confirmed booking"};
                    return response;
                }
            }
        }

        // Calculate cost: nights * price_per_night
        Property prop = properties.get(pending.property_id);
        int nights = daysBetween(pending.check_in_date, pending.check_out_date);
        float totalCost = <float>nights * prop.price_per_night;

        // Mark confirmed
        pending.confirmed = true;
        bookings[req.booking_id] = pending;

        ConfirmBookingResponse response = {success: true, booking_id: req.booking_id, total_cost: totalCost, message: "Booking confirmed"};
        return response;
    }
  remote function create_users(stream<User, grpc:Error?> clientStream) returns CreateUsersResponse|error {
        int count = 0;
        check clientStream.forEach(function(User u) {
            users[u.user_id] = u;
            count += 1;
        });
        CreateUsersResponse response = {success: true, users_created: count, message: "Users processed"};
        return response;
    }
remote function list_available_properties(ListAvailablePropertiesRequest req) returns stream<Property, error?>|error {
        Property[] results = [];

        foreach Property p in properties {
            boolean matchesLocation = req.location == "" || p.location == req.location;
            boolean matchesMinPrice = req.min_price == 0.0 || p.price_per_night >= req.min_price;
            boolean matchesMaxPrice = req.max_price == 0.0 || p.price_per_night <= req.max_price;

            if p.status == "AVAILABLE" && matchesLocation && matchesMinPrice && matchesMaxPrice {
                results.push(p);
            }
        }

        return results.toStream();
    }
  
}
