import ballerina/grpc;
import ballerina/protobuf;

public const string RENTAL_DESC = "0A0C72656E74616C2E70726F746F120672656E74616C22C8020A0850726F7065727479121F0A0B70726F70657274795F6964180120012809520A70726F7065727479496412170A07686F73745F69641802200128095206686F7374496412120A046E616D6518032001280952046E616D65121A0A086C6F636174696F6E18042001280952086C6F636174696F6E12390A0D70726F70657274795F7479706518052001280E32142E72656E74616C2E50726F706572747954797065520C70726F70657274795479706512260A0F70726963655F7065725F6E69676874180620012801520D70726963655065724E69676874122E0A0673746174757318072001280E32162E72656E74616C2E50726F70657274795374617475735206737461747573121D0A0A6D61785F67756573747318082001280552096D617847756573747312200A0B6465736372697074696F6E180920012809520B6465736372697074696F6E22760A0B5573657250726F66696C6512170A07757365725F6964180120012809520675736572496412120A046E616D6518022001280952046E616D6512140A05656D61696C1803200128095205656D61696C12240A04726F6C6518042001280E32102E72656E74616C2E55736572526F6C655204726F6C6522C3020A07426F6F6B696E67121D0A0A626F6F6B696E675F69641801200128095209626F6F6B696E67496412190A0867756573745F6964180220012809520767756573744964121F0A0B70726F70657274795F6964180320012809520A70726F7065727479496412230A0D70726F70657274795F6E616D65180420012809520C70726F70657274794E616D6512190A08636865636B5F696E1805200128095207636865636B496E121B0A09636865636B5F6F75741806200128095208636865636B4F757412160A066E696768747318072001280552066E696768747312260A0F70726963655F7065725F6E69676874180820012801520D70726963655065724E69676874121D0A0A746F74616C5F636F73741809200128015209746F74616C436F737412210A0C636F6E6669726D65645F6174180A20012809520B636F6E6669726D6564417422B1020A1241646450726F70657274795265717565737412170A07686F73745F69641801200128095206686F7374496412120A046E616D6518022001280952046E616D65121A0A086C6F636174696F6E18032001280952086C6F636174696F6E12390A0D70726F70657274795F7479706518042001280E32142E72656E74616C2E50726F706572747954797065520C70726F70657274795479706512260A0F70726963655F7065725F6E69676874180520012801520D70726963655065724E69676874122E0A0673746174757318062001280E32162E72656E74616C2E50726F70657274795374617475735206737461747573121D0A0A6D61785F67756573747318072001280552096D617847756573747312200A0B6465736372697074696F6E180820012809520B6465736372697074696F6E226A0A1341646450726F7065727479526573706F6E736512180A0773756363657373180120012808520773756363657373121F0A0B70726F70657274795F6964180220012809520A70726F7065727479496412180A076D65737361676518032001280952076D65737361676522AD010A134372656174655573657273526573706F6E736512180A077375636365737318012001280852077375636365737312230A0D637265617465645F636F756E74180220012805520C63726561746564436F756E7412250A0E72656A65637465645F636F756E74180320012805520D72656A6563746564436F756E7412160A066572726F727318042003280952066572726F727312180A076D65737361676518052001280952076D657373616765229A020A1555706461746550726F706572747952657175657374121F0A0B70726F70657274795F6964180120012809520A70726F7065727479496412170A07686F73745F69641802200128095206686F7374496412120A046E616D6518032001280952046E616D65121A0A086C6F636174696F6E18042001280952086C6F636174696F6E12260A0F70726963655F7065725F6E69676874180520012801520D70726963655065724E69676874122E0A0673746174757318062001280E32162E72656E74616C2E50726F70657274795374617475735206737461747573121D0A0A6D61785F67756573747318072001280552096D617847756573747312200A0B6465736372697074696F6E180820012809520B6465736372697074696F6E22740A1050726F7065727479526573706F6E736512180A077375636365737318012001280852077375636365737312180A076D65737361676518022001280952076D657373616765122C0A0870726F706572747918032001280B32102E72656E74616C2E50726F7065727479520870726F706572747922510A1552656D6F766550726F706572747952657175657374121F0A0B70726F70657274795F6964180120012809520A70726F7065727479496412170A07686F73745F69641802200128095206686F737449642288010A0C50726F70657274794C69737412300A0A70726F7065727469657318012003280B32102E72656E74616C2E50726F7065727479520A70726F7065727469657312160A06726567696F6E1802200128095206726567696F6E12140A05636F756E741803200128055205636F756E7412180A076D65737361676518042001280952076D65737361676522C3010A144C697374417661696C61626C6552657175657374121A0A086C6F636174696F6E18012001280952086C6F636174696F6E121B0A096D696E5F707269636518022001280152086D696E5072696365121B0A096D61785F707269636518032001280152086D61785072696365121D0A0A6D696E5F67756573747318042001280552096D696E47756573747312190A08636865636B5F696E1805200128095207636865636B496E121B0A09636865636B5F6F75741806200128095208636865636B4F757422380A1553656172636850726F706572747952657175657374121F0A0B70726F70657274795F6964180120012809520A70726F7065727479496422A1010A1653656172636850726F7065727479526573706F6E736512140A05666F756E641801200128085205666F756E64121C0A09617661696C61626C651802200128085209617661696C61626C6512250A0E7374617475735F6D657373616765180320012809520D7374617475734D657373616765122C0A0870726F706572747918042001280B32102E72656E74616C2E50726F7065727479520870726F706572747922A1010A13426F6F6B50726F70657274795265717565737412190A0867756573745F6964180120012809520767756573744964121F0A0B70726F70657274795F6964180220012809520A70726F7065727479496412190A08636865636B5F696E1803200128095207636865636B496E121B0A09636865636B5F6F75741804200128095208636865636B4F757412160A06677565737473180520012805520667756573747322AF010A14426F6F6B50726F7065727479526573706F6E7365121A0A0861636365707465641801200128085208616363657074656412200A0C636172745F6974656D5F6964180220012809520A636172744974656D496412180A076D65737361676518032001280952076D65737361676512160A066E696768747318042001280552066E696768747312270A0F657374696D617465645F746F74616C180520012801520E657374696D61746564546F74616C227D0A15436F6E6669726D426F6F6B696E675265717565737412190A0867756573745F696418012001280952076775657374496412200A0C636172745F6974656D5F6964180220012809520A636172744974656D496412270A0F6964656D706F74656E63795F6B6579180320012809520E6964656D706F74656E63794B657922B5010A13426F6F6B696E67436F6E6669726D6174696F6E121C0A09636F6E6669726D65641801200128085209636F6E6669726D6564122B0A08626F6F6B696E677318022003280B320F2E72656E74616C2E426F6F6B696E675208626F6F6B696E6773121D0A0A746F74616C5F636F73741803200128015209746F74616C436F737412180A076D65737361676518042001280952076D657373616765121A0A087265706C6179656418052001280852087265706C617965642A620A0E50726F7065727479537461747573121F0A1B50524F50455254595F5354415455535F554E5350454349464945441000120D0A09415641494C41424C451001120F0A0B554E415641494C41424C451002120F0A0B4D41494E54454E414E434510032A710A0C50726F706572747954797065121D0A1950524F50455254595F545950455F554E5350454349464945441000120D0A0941504152544D454E54100112090A05484F5553451002120F0A0B47554553545F484F555345100312090A054C4F4447451004120C0A0843414D505349544510052A3A0A0855736572526F6C6512190A15555345525F524F4C455F554E535045434946494544100012080A04484F5354100112090A054755455354100232EC040A0D52656E74616C5365727669636512470A0C6164645F70726F7065727479121A2E72656E74616C2E41646450726F7065727479526571756573741A1B2E72656E74616C2E41646450726F7065727479526573706F6E736512420A0C6372656174655F757365727312132E72656E74616C2E5573657250726F66696C651A1B2E72656E74616C2E4372656174655573657273526573706F6E73652801124A0A0F7570646174655F70726F7065727479121D2E72656E74616C2E55706461746550726F7065727479526571756573741A182E72656E74616C2E50726F7065727479526573706F6E736512460A0F72656D6F76655F70726F7065727479121D2E72656E74616C2E52656D6F766550726F7065727479526571756573741A142E72656E74616C2E50726F70657274794C697374124D0A196C6973745F617661696C61626C655F70726F70657274696573121C2E72656E74616C2E4C697374417661696C61626C65526571756573741A102E72656E74616C2E50726F7065727479300112500A0F7365617263685F70726F7065727479121D2E72656E74616C2E53656172636850726F7065727479526571756573741A1E2E72656E74616C2E53656172636850726F7065727479526573706F6E7365124A0A0D626F6F6B5F70726F7065727479121B2E72656E74616C2E426F6F6B50726F7065727479526571756573741A1C2E72656E74616C2E426F6F6B50726F7065727479526573706F6E7365124D0A0F636F6E6669726D5F626F6F6B696E67121D2E72656E74616C2E436F6E6669726D426F6F6B696E67526571756573741A1B2E72656E74616C2E426F6F6B696E67436F6E6669726D6174696F6E620670726F746F33";

public isolated client class RentalServiceClient {
    *grpc:AbstractClientEndpoint;

    private final grpc:Client grpcClient;

    public isolated function init(string url, *grpc:ClientConfiguration config) returns grpc:Error? {
        self.grpcClient = check new (url, config);
        check self.grpcClient.initStub(self, RENTAL_DESC);
    }

    isolated remote function add_property(AddPropertyRequest|ContextAddPropertyRequest req) returns AddPropertyResponse|grpc:Error {
        map<string|string[]> headers = {};
        AddPropertyRequest message;
        if req is ContextAddPropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/add_property", message, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <AddPropertyResponse>result;
    }

    isolated remote function add_propertyContext(AddPropertyRequest|ContextAddPropertyRequest req) returns ContextAddPropertyResponse|grpc:Error {
        map<string|string[]> headers = {};
        AddPropertyRequest message;
        if req is ContextAddPropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/add_property", message, headers);
        [anydata, map<string|string[]>] [result, respHeaders] = payload;
        return {content: <AddPropertyResponse>result, headers: respHeaders};
    }

    isolated remote function update_property(UpdatePropertyRequest|ContextUpdatePropertyRequest req) returns PropertyResponse|grpc:Error {
        map<string|string[]> headers = {};
        UpdatePropertyRequest message;
        if req is ContextUpdatePropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/update_property", message, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <PropertyResponse>result;
    }

    isolated remote function update_propertyContext(UpdatePropertyRequest|ContextUpdatePropertyRequest req) returns ContextPropertyResponse|grpc:Error {
        map<string|string[]> headers = {};
        UpdatePropertyRequest message;
        if req is ContextUpdatePropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/update_property", message, headers);
        [anydata, map<string|string[]>] [result, respHeaders] = payload;
        return {content: <PropertyResponse>result, headers: respHeaders};
    }

    isolated remote function remove_property(RemovePropertyRequest|ContextRemovePropertyRequest req) returns PropertyList|grpc:Error {
        map<string|string[]> headers = {};
        RemovePropertyRequest message;
        if req is ContextRemovePropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/remove_property", message, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <PropertyList>result;
    }

    isolated remote function remove_propertyContext(RemovePropertyRequest|ContextRemovePropertyRequest req) returns ContextPropertyList|grpc:Error {
        map<string|string[]> headers = {};
        RemovePropertyRequest message;
        if req is ContextRemovePropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/remove_property", message, headers);
        [anydata, map<string|string[]>] [result, respHeaders] = payload;
        return {content: <PropertyList>result, headers: respHeaders};
    }

    isolated remote function search_property(SearchPropertyRequest|ContextSearchPropertyRequest req) returns SearchPropertyResponse|grpc:Error {
        map<string|string[]> headers = {};
        SearchPropertyRequest message;
        if req is ContextSearchPropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/search_property", message, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <SearchPropertyResponse>result;
    }

    isolated remote function search_propertyContext(SearchPropertyRequest|ContextSearchPropertyRequest req) returns ContextSearchPropertyResponse|grpc:Error {
        map<string|string[]> headers = {};
        SearchPropertyRequest message;
        if req is ContextSearchPropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/search_property", message, headers);
        [anydata, map<string|string[]>] [result, respHeaders] = payload;
        return {content: <SearchPropertyResponse>result, headers: respHeaders};
    }

    isolated remote function book_property(BookPropertyRequest|ContextBookPropertyRequest req) returns BookPropertyResponse|grpc:Error {
        map<string|string[]> headers = {};
        BookPropertyRequest message;
        if req is ContextBookPropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/book_property", message, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <BookPropertyResponse>result;
    }

    isolated remote function book_propertyContext(BookPropertyRequest|ContextBookPropertyRequest req) returns ContextBookPropertyResponse|grpc:Error {
        map<string|string[]> headers = {};
        BookPropertyRequest message;
        if req is ContextBookPropertyRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/book_property", message, headers);
        [anydata, map<string|string[]>] [result, respHeaders] = payload;
        return {content: <BookPropertyResponse>result, headers: respHeaders};
    }

    isolated remote function confirm_booking(ConfirmBookingRequest|ContextConfirmBookingRequest req) returns BookingConfirmation|grpc:Error {
        map<string|string[]> headers = {};
        ConfirmBookingRequest message;
        if req is ContextConfirmBookingRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/confirm_booking", message, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <BookingConfirmation>result;
    }

    isolated remote function confirm_bookingContext(ConfirmBookingRequest|ContextConfirmBookingRequest req) returns ContextBookingConfirmation|grpc:Error {
        map<string|string[]> headers = {};
        ConfirmBookingRequest message;
        if req is ContextConfirmBookingRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeSimpleRPC("rental.RentalService/confirm_booking", message, headers);
        [anydata, map<string|string[]>] [result, respHeaders] = payload;
        return {content: <BookingConfirmation>result, headers: respHeaders};
    }

    isolated remote function create_users() returns Create_usersStreamingClient|grpc:Error {
        grpc:StreamingClient sClient = check self.grpcClient->executeClientStreaming("rental.RentalService/create_users");
        return new Create_usersStreamingClient(sClient);
    }

    isolated remote function list_available_properties(ListAvailableRequest|ContextListAvailableRequest req) returns stream<Property, grpc:Error?>|grpc:Error {
        map<string|string[]> headers = {};
        ListAvailableRequest message;
        if req is ContextListAvailableRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeServerStreaming("rental.RentalService/list_available_properties", message, headers);
        [stream<anydata, grpc:Error?>, map<string|string[]>] [result, _] = payload;
        PropertyStream outputStream = new PropertyStream(result);
        return new stream<Property, grpc:Error?>(outputStream);
    }

    isolated remote function list_available_propertiesContext(ListAvailableRequest|ContextListAvailableRequest req) returns ContextPropertyStream|grpc:Error {
        map<string|string[]> headers = {};
        ListAvailableRequest message;
        if req is ContextListAvailableRequest {
            message = req.content;
            headers = req.headers;
        } else {
            message = req;
        }
        var payload = check self.grpcClient->executeServerStreaming("rental.RentalService/list_available_properties", message, headers);
        [stream<anydata, grpc:Error?>, map<string|string[]>] [result, respHeaders] = payload;
        PropertyStream outputStream = new PropertyStream(result);
        return {content: new stream<Property, grpc:Error?>(outputStream), headers: respHeaders};
    }
}

public isolated client class Create_usersStreamingClient {
    private final grpc:StreamingClient sClient;

    isolated function init(grpc:StreamingClient sClient) {
        self.sClient = sClient;
    }

    isolated remote function sendUserProfile(UserProfile message) returns grpc:Error? {
        return self.sClient->send(message);
    }

    isolated remote function sendContextUserProfile(ContextUserProfile message) returns grpc:Error? {
        return self.sClient->send(message);
    }

    isolated remote function receiveCreateUsersResponse() returns CreateUsersResponse|grpc:Error? {
        var response = check self.sClient->receive();
        if response is () {
            return response;
        } else {
            [anydata, map<string|string[]>] [payload, _] = response;
            return <CreateUsersResponse>payload;
        }
    }

    isolated remote function receiveContextCreateUsersResponse() returns ContextCreateUsersResponse|grpc:Error? {
        var response = check self.sClient->receive();
        if response is () {
            return response;
        } else {
            [anydata, map<string|string[]>] [payload, headers] = response;
            return {content: <CreateUsersResponse>payload, headers: headers};
        }
    }

    isolated remote function sendError(grpc:Error response) returns grpc:Error? {
        return self.sClient->sendError(response);
    }

    isolated remote function complete() returns grpc:Error? {
        return self.sClient->complete();
    }
}

public class PropertyStream {
    private stream<anydata, grpc:Error?> anydataStream;

    public isolated function init(stream<anydata, grpc:Error?> anydataStream) {
        self.anydataStream = anydataStream;
    }

    public isolated function next() returns record {|Property value;|}|grpc:Error? {
        var streamValue = self.anydataStream.next();
        if streamValue is () {
            return streamValue;
        } else if streamValue is grpc:Error {
            return streamValue;
        } else {
            record {|Property value;|} nextRecord = {value: <Property>streamValue.value};
            return nextRecord;
        }
    }

    public isolated function close() returns grpc:Error? {
        return self.anydataStream.close();
    }
}

public type ContextUserProfileStream record {|
    stream<UserProfile, error?> content;
    map<string|string[]> headers;
|};

public type ContextPropertyStream record {|
    stream<Property, error?> content;
    map<string|string[]> headers;
|};

public type ContextBookPropertyRequest record {|
    BookPropertyRequest content;
    map<string|string[]> headers;
|};

public type ContextUserProfile record {|
    UserProfile content;
    map<string|string[]> headers;
|};

public type ContextUpdatePropertyRequest record {|
    UpdatePropertyRequest content;
    map<string|string[]> headers;
|};

public type ContextSearchPropertyResponse record {|
    SearchPropertyResponse content;
    map<string|string[]> headers;
|};

public type ContextConfirmBookingRequest record {|
    ConfirmBookingRequest content;
    map<string|string[]> headers;
|};

public type ContextPropertyResponse record {|
    PropertyResponse content;
    map<string|string[]> headers;
|};

public type ContextListAvailableRequest record {|
    ListAvailableRequest content;
    map<string|string[]> headers;
|};

public type ContextPropertyList record {|
    PropertyList content;
    map<string|string[]> headers;
|};

public type ContextAddPropertyResponse record {|
    AddPropertyResponse content;
    map<string|string[]> headers;
|};

public type ContextRemovePropertyRequest record {|
    RemovePropertyRequest content;
    map<string|string[]> headers;
|};

public type ContextBookingConfirmation record {|
    BookingConfirmation content;
    map<string|string[]> headers;
|};

public type ContextAddPropertyRequest record {|
    AddPropertyRequest content;
    map<string|string[]> headers;
|};

public type ContextCreateUsersResponse record {|
    CreateUsersResponse content;
    map<string|string[]> headers;
|};

public type ContextSearchPropertyRequest record {|
    SearchPropertyRequest content;
    map<string|string[]> headers;
|};

public type ContextProperty record {|
    Property content;
    map<string|string[]> headers;
|};

public type ContextBookPropertyResponse record {|
    BookPropertyResponse content;
    map<string|string[]> headers;
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type BookPropertyRequest record {|
    string guest_id = "";
    string property_id = "";
    string check_in = "";
    string check_out = "";
    int guests = 0;
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type UserProfile record {|
    string user_id = "";
    string name = "";
    string email = "";
    UserRole role = USER_ROLE_UNSPECIFIED;
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type UpdatePropertyRequest record {|
    string property_id = "";
    string host_id = "";
    string name = "";
    string location = "";
    float price_per_night = 0.0;
    PropertyStatus status = PROPERTY_STATUS_UNSPECIFIED;
    int max_guests = 0;
    string description = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type SearchPropertyResponse record {|
    boolean found = false;
    boolean available = false;
    string status_message = "";
    Property property = {};
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type Booking record {|
    string booking_id = "";
    string guest_id = "";
    string property_id = "";
    string property_name = "";
    string check_in = "";
    string check_out = "";
    int nights = 0;
    float price_per_night = 0.0;
    float total_cost = 0.0;
    string confirmed_at = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type ConfirmBookingRequest record {|
    string guest_id = "";
    string cart_item_id = "";
    string idempotency_key = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type PropertyResponse record {|
    boolean success = false;
    string message = "";
    Property property = {};
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type ListAvailableRequest record {|
    string location = "";
    float min_price = 0.0;
    float max_price = 0.0;
    int min_guests = 0;
    string check_in = "";
    string check_out = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type PropertyList record {|
    Property[] properties = [];
    string region = "";
    int count = 0;
    string message = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type AddPropertyResponse record {|
    boolean success = false;
    string property_id = "";
    string message = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type RemovePropertyRequest record {|
    string property_id = "";
    string host_id = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type BookingConfirmation record {|
    boolean confirmed = false;
    Booking[] bookings = [];
    float total_cost = 0.0;
    string message = "";
    boolean replayed = false;
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type AddPropertyRequest record {|
    string host_id = "";
    string name = "";
    string location = "";
    PropertyType property_type = PROPERTY_TYPE_UNSPECIFIED;
    float price_per_night = 0.0;
    PropertyStatus status = PROPERTY_STATUS_UNSPECIFIED;
    int max_guests = 0;
    string description = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type CreateUsersResponse record {|
    boolean success = false;
    int created_count = 0;
    int rejected_count = 0;
    string[] errors = [];
    string message = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type SearchPropertyRequest record {|
    string property_id = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type Property record {|
    string property_id = "";
    string host_id = "";
    string name = "";
    string location = "";
    PropertyType property_type = PROPERTY_TYPE_UNSPECIFIED;
    float price_per_night = 0.0;
    PropertyStatus status = PROPERTY_STATUS_UNSPECIFIED;
    int max_guests = 0;
    string description = "";
|};

@protobuf:Descriptor {value: RENTAL_DESC}
public type BookPropertyResponse record {|
    boolean accepted = false;
    string cart_item_id = "";
    string message = "";
    int nights = 0;
    float estimated_total = 0.0;
|};

public enum PropertyStatus {
    PROPERTY_STATUS_UNSPECIFIED, AVAILABLE, UNAVAILABLE, MAINTENANCE
}

public enum PropertyType {
    PROPERTY_TYPE_UNSPECIFIED, APARTMENT, HOUSE, GUEST_HOUSE, LODGE, CAMPSITE
}

public enum UserRole {
    USER_ROLE_UNSPECIFIED, HOST, GUEST
}
