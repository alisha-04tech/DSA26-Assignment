import ballerina/http;

// ============================================================================
// ERROR MAPPING
// ============================================================================
// The ONLY place that knows business meanings become HTTP numbers.
// store.bal raises NotFoundError / ConflictError / ValidationError and never
// mentions HTTP; this function picks the wire representation. Swap this layer
// for gRPC and the same three errors become NOT_FOUND / ABORTED /
// INVALID_ARGUMENT with no change to the business rules.
function mapError(error e) returns http:NotFound|http:Conflict|http:BadRequest {
    if e is NotFoundError {
        http:NotFound nf = {body: {message: "Resource not found", details: e.message()}};
        return nf;
    }
    if e is ConflictError {
        http:Conflict cf = {body: {message: "Conflicts with current state", details: e.message()}};
        return cf;
    }
    http:BadRequest br = {body: {message: "Invalid request", details: e.message()}};
    return br;
}

// ============================================================================
// THE SERVICE
// ============================================================================
service /library on new http:Listener(9090) {

    function init() {
        seed();
    }

    // ---- health ----------------------------------------------------------
    resource function get health() returns json {
                return {"status": "UP", "service": "library-management", "today": today()};
    }

    // ---- assets: read ----------------------------------------------------

    // GET /library/assets
    // GET /library/assets?institution=...&site=...
    resource function get assets(string? institution, string? site) returns Asset[] {
        if institution is () && site is () {
            return listAssets();
        }
        return filterAssets(institution, site);
    }

    // GET /library/assets/{assetTag}
    resource function get assets/[string assetTag]() returns Asset|http:NotFound {
        Asset? found = getAsset(assetTag);
        if found is () {
            http:NotFound nf = {
                body: {message: string `Asset '${assetTag}' not found`}
            };
            return nf;
        }
        return found;
    }

    // ---- assets: write ---------------------------------------------------

    // POST /library/assets
    resource function post assets(Asset newAsset)
            returns http:Created|http:NotFound|http:Conflict|http:BadRequest {
        Asset|error created = addAsset(newAsset);
        if created is error {
            return mapError(created);
        }
        http:Created result = {
            headers: {"Location": string `/library/assets/${created.assetTag}`},
            body: created
        };
        return result;
    }

    // PUT /library/assets/{assetTag}
    resource function put assets/[string assetTag](AssetUpdate patch)
            returns Asset|http:NotFound|http:Conflict|http:BadRequest {
        Asset|error updated = updateAsset(assetTag, patch);
        if updated is error {
            return mapError(updated);
        }
        return updated;
    }

    // DELETE /library/assets/{assetTag}
    resource function delete assets/[string assetTag]()
            returns Asset|http:NotFound|http:Conflict|http:BadRequest {
        Asset|error removed = removeAsset(assetTag);
        if removed is error {
            return mapError(removed);
        }
        return removed;
    }

    // ---- schedules -------------------------------------------------------

    // GET /library/assets/{assetTag}/schedules
    resource function get assets/[string assetTag]/schedules()
            returns Schedule[]|http:NotFound|http:Conflict|http:BadRequest {
        Schedule[]|error result = getSchedules(assetTag);
        if result is error {
            return mapError(result);
        }
        return result;
    }

    // POST /library/assets/{assetTag}/schedules
    resource function post assets/[string assetTag]/schedules(Schedule s)
            returns http:Created|http:NotFound|http:Conflict|http:BadRequest {
        Schedule|error added = addSchedule(assetTag, s);
        if added is error {
            return mapError(added);
        }
        http:Created created = {body: added};
        return created;
    }

    // DELETE /library/assets/{assetTag}/schedules/{scheduleId}
    resource function delete assets/[string assetTag]/schedules/[string scheduleId]()
            returns Schedule|http:NotFound|http:Conflict|http:BadRequest {
        Schedule|error removed = removeSchedule(assetTag, scheduleId);
        if removed is error {
            return mapError(removed);
        }
        return removed;
    }

    // ---- overdue dashboard -----------------------------------------------

    // GET /library/overdue
    // GET /library/overdue?institution=...
    resource function get overdue(string? institution)
            returns OverdueEntry[]|http:NotFound|http:Conflict|http:BadRequest {
        OverdueEntry[]|error result = findOverdue(institution);
        if result is error {
            return mapError(result);
        }
        return result;
    }

    // ---- loaning & booking -----------------------------------------------

    // POST /library/assets/{assetTag}/loan
    resource function post assets/[string assetTag]/loan(LoanRequest req)
            returns http:Ok|http:NotFound|http:Conflict|http:BadRequest {
        Asset|error result = loanAsset(assetTag, req);
        if result is error {
            return mapError(result);
        }
                http:Ok ok = {body: result};
        return ok;
    }

    // POST /library/assets/{assetTag}/checkin
    // Named "checkin" because `return` is a Ballerina keyword.
    resource function post assets/[string assetTag]/checkin()
            returns http:Ok|http:NotFound|http:Conflict|http:BadRequest {
        Asset|error result = returnAsset(assetTag);
        if result is error {
            return mapError(result);
        }
                http:Ok ok = {body: result};
        return ok;
    }
}
