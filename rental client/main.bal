import ballerina/io;

public function main() returns error? {
    RentalServiceClient rentalClient = check new ("http://localhost:9090");

    io:println("=== Rental System Client ===");

    AddPropertyRequest newProperty = {
        name: "Cozy Beach House",
        location: "Swakopmund",
        property_type: "House",
        price_per_night: 850.0,
        status: "AVAILABLE"
    };

    AddPropertyResponse response = check rentalClient->add_property(newProperty);
    io:println("Property created with ID: ", response.property_id);

    SearchPropertyRequest searchReq = {property_id: response.property_id};
    SearchPropertyResponse searchResult = check rentalClient->search_property(searchReq);

    if searchResult.found {
        io:println("Found property: ", searchResult.property.name, " in ", searchResult.property.location);
    } else {
        io:println("Search result: ", searchResult.status_message);
    }

    UpdatePropertyRequest updateReq = {
        property_id: response.property_id,
        name: "Cozy Beach House",
        location: "Swakopmund",
        property_type: "House",
        price_per_night: 950.0,
        status: "AVAILABLE"
    };
    UpdatePropertyResponse updateResult = check rentalClient->update_property(updateReq);
    io:println("Update result: ", updateResult.message);

    RemovePropertyRequest removeReq = {property_id: response.property_id};
    RemovePropertyResponse removeResult = check rentalClient->remove_property(removeReq);
    io:println("Remaining properties after removal: ", removeResult.remaining_properties.length());
AddPropertyRequest secondProperty = {
        name: "Mountain Cabin",
        location: "Windhoek",
        property_type: "Cabin",
        price_per_night: 500.0,
        status: "AVAILABLE"
    };
    AddPropertyResponse secondResponse = check rentalClient->add_property(secondProperty);
    io:println("Second property created with ID: ", secondResponse.property_id);

    BookPropertyRequest bookReq = {
        property_id: secondResponse.property_id,
        guest_name: "Jollene",
        check_in_date: "2026-09-01",
        check_out_date: "2026-09-04"
    };
    BookPropertyResponse bookResult = check rentalClient->book_property(bookReq);
    io:println("Booking result: ", bookResult.message, " | Booking ID: ", bookResult.booking_id);

    ConfirmBookingRequest confirmReq = {booking_id: bookResult.booking_id};
    ConfirmBookingResponse confirmResult = check rentalClient->confirm_booking(confirmReq);
    io:println("Confirm result: ", confirmResult.message, " | Total cost: ", confirmResult.total_cost);

    ListAvailablePropertiesRequest listReq = {location: "", min_price: 0.0, max_price: 0.0};
    stream<Property, error?> propertyStream = check rentalClient->list_available_properties(listReq);

    io:println("--- Available Properties ---");
    check propertyStream.forEach(function(Property p) {
        io:println(p.property_id, " | ", p.name, " | ", p.location, " | N$", p.price_per_night);
    });

    Create_usersStreamingClient userStream = check rentalClient->create_users();

    User user1 = {user_id: "U1", name: "Jollene", role: "GUEST", email: "jollene@example.com"};
    User user2 = {user_id: "U2", name: "Host One", role: "HOST", email: "host1@example.com"};

    check userStream->sendUser(user1);
    check userStream->sendUser(user2);
    check userStream->complete();

    CreateUsersResponse? usersResult = check userStream->receiveCreateUsersResponse();
    if usersResult is CreateUsersResponse {
        io:println("Users created: ", usersResult.users_created, " | ", usersResult.message);
    }
}
