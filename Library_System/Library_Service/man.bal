import ballerina/http;

table<Asset> key(assetTag) assets = table [
    {
        assetTag: "NUST-LIB-3DP-001",
        name: "Pro-Series 3D Printer",
        description: "High-precision laboratory printer for simulation and prototype development.",
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Innovation Lab",
        status: "AVAILABLE",
        dateAcquired: "2024-03-10",
        components: [],
        schedules: [
            {
                scheduleId: "SCH-001",
                scheduleType: "MAINTENANCE",
                dueDate: "2026-08-01",
                description: "Quarterly calibration and nozzle cleaning"
            }
        ],
        workOrders: []
    }
];

service / on new http:Listener(8080) {

    // =========================================================
    // GET ALL ASSETS
    // =========================================================

    resource function get assets() returns Asset[] {
        return assets.toArray();
    }

    // =========================================================
    // GET ASSET BY ASSET TAG
    // =========================================================

    resource function get assets/[string assetTag]()
            returns Asset|http:NotFound {

        Asset? asset = assets[assetTag];

        if asset is Asset {
            return asset;
        }

        return http:NOT_FOUND;
    }

    // =========================================================
    // CREATE ASSET
    // =========================================================

    resource function post assets(@http:Payload Asset asset)
            returns Asset|http:Conflict {

        if assets.hasKey(asset.assetTag) {
            return http:CONFLICT;
        }

        assets.add(asset);

        return asset;
    }

    // =========================================================
    // UPDATE ASSET
    // =========================================================

    resource function put assets/[string assetTag](
            @http:Payload Asset asset)
            returns Asset|http:NotFound|http:BadRequest {

        if asset.assetTag != assetTag {
            return http:BAD_REQUEST;
        }

        if !assets.hasKey(assetTag) {
            return http:NOT_FOUND;
        }

        _ = assets.remove(assetTag);
        assets.add(asset);

        return asset;
    }

    // =========================================================
    // DELETE ASSET
    // =========================================================

    resource function delete assets/[string assetTag]()
            returns http:NoContent|http:NotFound {

        if !assets.hasKey(assetTag) {
            return http:NOT_FOUND;
        }

        _ = assets.remove(assetTag);

        return http:NO_CONTENT;
    }

    // =========================================================
    // FILTER BY INSTITUTION
    // =========================================================

    resource function get assets/institution/[string institution]()
            returns Asset[] {

        Asset[] results = [];

        foreach Asset asset in assets {
            if asset.institution == institution {
                results.push(asset);
            }
        }

        return results;
    }

    // =========================================================
    // FILTER BY CAMPUS / SITE
    // =========================================================

    resource function get assets/campus/[string site]()
            returns Asset[] {

        Asset[] results = [];

        foreach Asset asset in assets {
            if asset.site == site {
                results.push(asset);
            }
        }

        return results;
    }

    // =========================================================
    // OVERDUE MAINTENANCE
    // =========================================================

    resource function get assets/overdue()
            returns OverdueAsset[] {

        string today = "2026-08-13";

        OverdueAsset[] overdue = [];

        foreach Asset asset in assets {

            foreach Schedule schedule in asset.schedules {

                if schedule.dueDate < today {

                    overdue.push({
                        assetTag: asset.assetTag,
                        name: asset.name,
                        institution: asset.institution,
                        site: asset.site,
                        scheduleId: schedule.scheduleId,
                        scheduleType: schedule.scheduleType,
                        dueDate: schedule.dueDate,
                        description: schedule.description
                    });
                }
            }
        }

        return overdue;
    }

    // =========================================================
    // GET ALL MAINTENANCE SCHEDULES
    // =========================================================

    resource function get assets/maintenance()
            returns Schedule[] {

        Schedule[] schedules = [];

        foreach Asset asset in assets {

            foreach Schedule schedule in asset.schedules {
                schedules.push(schedule);
            }
        }

        return schedules;
    }

    // =========================================================
    // GET MAINTENANCE FOR ONE ASSET
    // =========================================================

    resource function get assets/[string assetTag]/maintenance()
            returns Schedule[]|http:NotFound {

        Asset? asset = assets[assetTag];

        if asset is Asset {
            return asset.schedules;
        }

        return http:NOT_FOUND;
    }

    // =========================================================
    // ADD MAINTENANCE SCHEDULE
    // =========================================================

    resource function post assets/[string assetTag]/schedules(
            @http:Payload Schedule schedule)
            returns Schedule|http:NotFound|http:Conflict {

        Asset? asset = assets[assetTag];

        if asset is () {
            return http:NOT_FOUND;
        }

        foreach Schedule existing in asset.schedules {

            if existing.scheduleId == schedule.scheduleId {
                return http:CONFLICT;
            }
        }

        asset.schedules.push(schedule);

        return schedule;
    }

    // =========================================================
    // DELETE MAINTENANCE SCHEDULE
    // =========================================================

    resource function delete assets/[string assetTag]/schedules/[string scheduleId]()
            returns http:NoContent|http:NotFound {

        Asset? asset = assets[assetTag];

        if asset is () {
            return http:NOT_FOUND;
        }

        int index = -1;

        foreach int i in 0 ..< asset.schedules.length() {

            if asset.schedules[i].scheduleId == scheduleId {
                index = i;
                break;
            }
        }

        if index == -1 {
            return http:NOT_FOUND;
        }

        _ = asset.schedules.remove(index);

        return http:NO_CONTENT;
    }
}
