import ballerina/http;

service /library on new http:Listener(9090) {

    // Runs once when the service starts.
    function init() {
        seed();
    }

    // GET /library/assets
    resource function get assets() returns Asset[] {
        return listAssets();
    }

    // GET /library/assets/{assetTag}
    resource function get assets/[string assetTag]() returns Asset|http:NotFound {
        Asset? found = getAsset(assetTag);
        if found is () {
            http:NotFound notFound = {
                body: {message: string `Asset '${assetTag}' not found`}
            };
            return notFound;
        }
        return found;
    }
}
