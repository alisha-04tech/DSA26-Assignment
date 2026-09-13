import ballerina/http;
import ballerina/io;

final http:Client apiClient = check new ("http://localhost:8080");

function printHeader(string title) {
    io:println("");
    io:println("========================================");
    io:println("       " + title);
    io:println("========================================");
}

// =========================================================
// VIEW ALL ASSETS
// =========================================================

function viewAllAssets() returns error? {

    http:Response response = check apiClient->get("/assets");

    if response.statusCode != 200 {
        io:println("Unable to retrieve assets.");
        return;
    }

    json|http:ClientError payload = response.getJsonPayload();

    if payload is http:ClientError {
        return payload;
    }

    Asset[] assets = check payload.cloneWithType();

    printHeader("ALL LIBRARY ASSETS");

    if assets.length() == 0 {
        io:println("No assets found.");
        return;
    }

    foreach Asset asset in assets {
        io:println("");
        io:println("Asset Tag:    " + asset.assetTag);
        io:println("Name:         " + asset.name);
        io:println("Description:  " + asset.description);
        io:println("Institution:  " + asset.institution);
        io:println("Campus:       " + asset.site);
        io:println("Status:       " + asset.status.toString());
        io:println("Acquired:     " + asset.dateAcquired);
        io:println("----------------------------------------");
    }
}

// =========================================================
// VIEW ASSET BY TAG
// =========================================================

function viewAsset() returns error? {

    printHeader("VIEW ASSET");

    io:print("Enter asset tag: ");
    string|error assetTag = io:readln();

    if assetTag is error {
        return assetTag;
    }

    http:Response response = check apiClient->get(
        "/assets/" + assetTag
    );

    if response.statusCode == 404 {
        io:println("");
        io:println("Asset not found.");
        return;
    }

    if response.statusCode != 200 {
        io:println("");
        io:println("Unable to retrieve asset.");
        return;
    }

    json|http:ClientError payload = response.getJsonPayload();

    if payload is http:ClientError {
        return payload;
    }

    Asset asset = check payload.cloneWithType();

    io:println("");
    io:println("Asset Tag:    " + asset.assetTag);
    io:println("Name:         " + asset.name);
    io:println("Description:  " + asset.description);
    io:println("Institution:  " + asset.institution);
    io:println("Campus:       " + asset.site);
    io:println("Status:       " + asset.status.toString());
    io:println("Acquired:     " + asset.dateAcquired);
}

// =========================================================
// VIEW BY INSTITUTION
// =========================================================

function viewByInstitution() returns error? {

    io:print("Enter institution: ");
    string|error institution = io:readln();

    if institution is error {
        return institution;
    }

    http:Response response = check apiClient->get(
        "/assets/institution/" + institution
    );

    if response.statusCode != 200 {
        io:println("Unable to retrieve assets.");
        return;
    }

    json|http:ClientError payload = response.getJsonPayload();

    if payload is http:ClientError {
        return payload;
    }

    Asset[] assets = check payload.cloneWithType();

    printHeader("ASSETS BY INSTITUTION");

    if assets.length() == 0 {
        io:println("No assets found for this institution.");
        return;
    }

    foreach Asset asset in assets {
        io:println("");
        io:println("Asset Tag: " + asset.assetTag);
        io:println("Name:      " + asset.name);
        io:println("Campus:    " + asset.site);
        io:println("Status:    " + asset.status.toString());
        io:println("----------------------------------------");
    }
}

// =========================================================
// VIEW BY CAMPUS
// =========================================================

function viewByCampus() returns error? {

    io:print("Enter campus/site: ");
    string|error site = io:readln();

    if site is error {
        return site;
    }

    http:Response response = check apiClient->get(
        "/assets/campus/" + site
    );

    if response.statusCode != 200 {
        io:println("Unable to retrieve assets.");
        return;
    }

    json|http:ClientError payload = response.getJsonPayload();

    if payload is http:ClientError {
        return payload;
    }

    Asset[] assets = check payload.cloneWithType();

    printHeader("ASSETS BY CAMPUS");

    if assets.length() == 0 {
        io:println("No assets found at this campus/site.");
        return;
    }

    foreach Asset asset in assets {
        io:println("");
        io:println("Asset Tag:    " + asset.assetTag);
        io:println("Name:         " + asset.name);
        io:println("Institution:  " + asset.institution);
        io:println("Status:       " + asset.status.toString());
        io:println("----------------------------------------");
    }
}

// =========================================================
// OVERDUE DASHBOARD
// =========================================================

function overdueDashboard() returns error? {

    http:Response response = check apiClient->get("/assets/overdue");

    if response.statusCode != 200 {
        io:println("Unable to retrieve overdue items.");
        return;
    }

    json|http:ClientError payload = response.getJsonPayload();

    if payload is http:ClientError {
        return payload;
    }

    OverdueAsset[] overdue = check payload.cloneWithType();

    printHeader("OVERDUE DASHBOARD");

    if overdue.length() == 0 {
        io:println("No overdue maintenance items.");
        return;
    }

    io:println("OVERDUE ITEMS: " + overdue.length().toString());

    foreach OverdueAsset item in overdue {
        io:println("");
        io:println("Asset Tag:    " + item.assetTag);
        io:println("Asset:        " + item.name);
        io:println("Institution:  " + item.institution);
        io:println("Campus:       " + item.site);
        io:println("Schedule:     " + item.scheduleId);
        io:println("Type:         " + item.scheduleType);
        io:println("Due Date:     " + item.dueDate);
        io:println("Description:  " + item.description);
        io:println("----------------------------------------");
    }
}

// =========================================================
// VIEW ASSET MAINTENANCE
// =========================================================

function viewAssetMaintenance() returns error? {

    io:print("Enter asset tag: ");
    string|error assetTag = io:readln();

    if assetTag is error {
        return assetTag;
    }

    http:Response response = check apiClient->get(
        "/assets/" + assetTag + "/maintenance"
    );

    if response.statusCode == 404 {
        io:println("");
        io:println("Asset not found.");
        return;
    }

    if response.statusCode != 200 {
        io:println("");
        io:println("Unable to retrieve maintenance information.");
        return;
    }

    json|http:ClientError payload = response.getJsonPayload();

    if payload is http:ClientError {
        return payload;
    }

    Schedule[] schedules = check payload.cloneWithType();

    printHeader("ASSET MAINTENANCE");

    io:println("Asset Tag: " + assetTag);

    if schedules.length() == 0 {
        io:println("");
        io:println("No maintenance schedules found.");
        return;
    }

    foreach Schedule schedule in schedules {
        io:println("");
        io:println("Schedule ID:  " + schedule.scheduleId);
        io:println("Type:         " + schedule.scheduleType);
        io:println("Due Date:     " + schedule.dueDate);
        io:println("Description:  " + schedule.description);
        io:println("----------------------------------------");
    }
}

// =========================================================
// ADD MAINTENANCE SCHEDULE
// =========================================================

function addMaintenanceSchedule() returns error? {

    printHeader("ADD MAINTENANCE SCHEDULE");

    io:print("Asset Tag: ");
    string|error assetTag = io:readln();

    if assetTag is error {
        return assetTag;
    }

    io:print("Schedule ID: ");
    string|error scheduleId = io:readln();

    if scheduleId is error {
        return scheduleId;
    }

    io:print("Schedule Type: ");
    string|error scheduleType = io:readln();

    if scheduleType is error {
        return scheduleType;
    }

    io:print("Due Date (YYYY-MM-DD): ");
    string|error dueDate = io:readln();

    if dueDate is error {
        return dueDate;
    }

    io:print("Description: ");
    string|error description = io:readln();

    if description is error {
        return description;
    }

    Schedule schedule = {
        scheduleId: scheduleId,
        scheduleType: scheduleType,
        dueDate: dueDate,
        description: description
    };

    http:Response response = check apiClient->post(
        "/assets/" + assetTag + "/schedules",
        schedule
    );

    if response.statusCode == 404 {
        io:println("");
        io:println("Asset not found.");
        return;
    }

    if response.statusCode == 409 {
        io:println("");
        io:println("A schedule with that ID already exists.");
        return;
    }

    if response.statusCode != 200 {
        io:println("");
        io:println("Unable to create maintenance schedule.");
        io:println("HTTP Status: " + response.statusCode.toString());
        return;
    }

    io:println("");
    io:println("Maintenance schedule created successfully.");
    io:println("Schedule ID: " + scheduleId);
}

// =========================================================
// DELETE MAINTENANCE SCHEDULE
// =========================================================

function deleteMaintenanceSchedule() returns error? {

    printHeader("DELETE MAINTENANCE SCHEDULE");

    io:print("Asset Tag: ");
    string|error assetTag = io:readln();

    if assetTag is error {
        return assetTag;
    }

    io:print("Schedule ID: ");
    string|error scheduleId = io:readln();

    if scheduleId is error {
        return scheduleId;
    }

    http:Response response = check apiClient->delete(
        "/assets/" + assetTag + "/schedules/" + scheduleId
    );

    if response.statusCode == 204 {
        io:println("");
        io:println("Maintenance schedule deleted successfully.");
        return;
    }

    if response.statusCode == 404 {
        io:println("");
        io:println("Asset or maintenance schedule not found.");
        return;
    }

    io:println("");
    io:println("Delete failed.");
}

// =========================================================
// CREATE ASSET
// =========================================================

function createAsset() returns error? {

    printHeader("CREATE NEW ASSET");

    io:print("Asset Tag: ");
    string|error assetTag = io:readln();

    if assetTag is error {
        return assetTag;
    }

    io:print("Name: ");
    string|error name = io:readln();

    if name is error {
        return name;
    }

    io:print("Description: ");
    string|error description = io:readln();

    if description is error {
        return description;
    }

    io:print("Institution: ");
    string|error institution = io:readln();

    if institution is error {
        return institution;
    }

    io:print("Campus/Site: ");
    string|error site = io:readln();

    if site is error {
        return site;
    }

    io:print("Status (AVAILABLE/LOANED_OUT/OCCUPIED/UNDER_MAINTENANCE/DISPOSED): ");
    string|error statusInput = io:readln();

    if statusInput is error {
        return statusInput;
    }

    if statusInput != "AVAILABLE" && statusInput != "LOANED_OUT" &&
        statusInput != "OCCUPIED" && statusInput != "UNDER_MAINTENANCE" &&
        statusInput != "DISPOSED" {
        io:println("Invalid asset status.");
        return;
    }

    AssetStatus status = <AssetStatus>statusInput;

    io:print("Date Acquired (YYYY-MM-DD): ");
    string|error dateAcquired = io:readln();

    if dateAcquired is error {
        return dateAcquired;
    }

    Asset asset = {
        assetTag: assetTag,
        name: name,
        description: description,
        institution: institution,
        site: site,
        status: status,
        dateAcquired: dateAcquired,
        components: [],
        schedules: [],
        workOrders: []
    };

    http:Response response = check apiClient->post(
        "/assets",
        asset
    );

    if response.statusCode == 409 {
        io:println("");
        io:println("An asset with this asset tag already exists.");
        return;
    }

    if response.statusCode != 201 {
        io:println("");
        io:println("Unable to create asset.");
        io:println("HTTP Status: " + response.statusCode.toString());
        return;
    }

    io:println("");
    io:println("Asset created successfully.");
    io:println("Asset Tag: " + assetTag);
}

// =========================================================
// UPDATE ASSET
// =========================================================

function updateAsset() returns error? {

    printHeader("UPDATE ASSET");

    io:print("Enter asset tag to update: ");
    string|error assetTag = io:readln();

    if assetTag is error {
        return assetTag;
    }

    http:Response existingResponse = check apiClient->get(
        "/assets/" + assetTag
    );

    if existingResponse.statusCode == 404 {
        io:println("");
        io:println("Asset not found.");
        return;
    }

    if existingResponse.statusCode != 200 {
        io:println("");
        io:println("Unable to retrieve asset.");
        return;
    }

    json|http:ClientError existingPayload =
        existingResponse.getJsonPayload();

    if existingPayload is http:ClientError {
        return existingPayload;
    }

    Asset existingAsset = check existingPayload.cloneWithType();

    io:println("");
    io:println("Current asset:");
    io:println("Name:        " + existingAsset.name);
    io:println("Description: " + existingAsset.description);
    io:println("Institution: " + existingAsset.institution);
    io:println("Campus:      " + existingAsset.site);
    io:println("Status:      " + existingAsset.status.toString());
    io:println("Acquired:    " + existingAsset.dateAcquired);

    io:println("");
    io:println("Enter the new information.");

    io:print("Name: ");
    string|error name = io:readln();

    if name is error {
        return name;
    }

    io:print("Description: ");
    string|error description = io:readln();

    if description is error {
        return description;
    }

    io:print("Institution: ");
    string|error institution = io:readln();

    if institution is error {
        return institution;
    }

    io:print("Campus/Site: ");
    string|error site = io:readln();

    if site is error {
        return site;
    }

    io:print("Status (AVAILABLE/LOANED_OUT/OCCUPIED/UNDER_MAINTENANCE/DISPOSED): ");
    string|error statusInput = io:readln();

    if statusInput is error {
        return statusInput;
    }

    if statusInput != "AVAILABLE" && statusInput != "LOANED_OUT" &&
        statusInput != "OCCUPIED" && statusInput != "UNDER_MAINTENANCE" &&
        statusInput != "DISPOSED" {
        io:println("Invalid asset status.");
        return;
    }

    AssetStatus status = <AssetStatus>statusInput;

    io:print("Date Acquired (YYYY-MM-DD): ");
    string|error dateAcquired = io:readln();

    if dateAcquired is error {
        return dateAcquired;
    }

    Asset updatedAsset = {
        assetTag: assetTag,
        name: name,
        description: description,
        institution: institution,
        site: site,
        status: status,
        dateAcquired: dateAcquired,
        components: existingAsset.components,
        schedules: existingAsset.schedules,
        workOrders: existingAsset.workOrders
    };

    http:Response response = check apiClient->put(
        "/assets/" + assetTag,
        updatedAsset
    );

    if response.statusCode == 404 {
        io:println("");
        io:println("Asset not found.");
        return;
    }

    if response.statusCode == 400 {
        io:println("");
        io:println("Asset tag cannot be changed.");
        return;
    }

    if response.statusCode != 200 {
        io:println("");
        io:println("Unable to update asset.");
        io:println("HTTP Status: " + response.statusCode.toString());
        return;
    }

    io:println("");
    io:println("Asset updated successfully.");
}

// =========================================================
// DELETE ASSET
// =========================================================

function deleteAsset() returns error? {

    printHeader("DELETE ASSET");

    io:print("Enter asset tag: ");
    string|error assetTagInput = io:readln();

    if assetTagInput is error {
        return assetTagInput;
    }

    string assetTag = assetTagInput;

    io:println("");
    io:println("Are you sure you want to delete asset " + assetTag + "?");
    io:print("Type YES to confirm: ");

    string|error confirmationInput = io:readln();

    if confirmationInput is error {
        return confirmationInput;
    }

    string confirmation = confirmationInput;

    if confirmation != "YES" {
        io:println("");
        io:println("Delete cancelled.");
        return;
    }

    http:Response response = check apiClient->delete(
        "/assets/" + assetTag
    );

    if response.statusCode == 404 {
        io:println("");
        io:println("Asset not found.");
        return;
    }

    if response.statusCode != 204 {
        io:println("");
        io:println("Unable to delete asset.");
        io:println("HTTP Status: " + response.statusCode.toString());
        return;
    }

    io:println("");
    io:println("Asset deleted successfully.");
}

// =========================================================
// MENU
// =========================================================

function showMenu() {

    printHeader("MINISTRY LIBRARY SYSTEM");

    io:println("1.  View All Assets");
    io:println("2.  View By Institution");
    io:println("3.  View By Campus");
    io:println("4.  Overdue Dashboard");
    io:println("5.  View Asset Maintenance");
    io:println("6.  Add Maintenance Schedule");
    io:println("7.  Delete Maintenance Schedule");
    io:println("8.  View Asset By Tag");
    io:println("9.  Create New Asset");
    io:println("10. Update Asset");
    io:println("11. Delete Asset");
    io:println("0.  Exit");

    io:println("");
    io:print("Select an option: ");
}

// =========================================================
// MAIN
// =========================================================

public function main() returns error? {

    boolean running = true;

    while running {

        showMenu();

        string|error input = io:readln();

        if input is error {
            return input;
        }

        match input {

            "1" => {
                check viewAllAssets();
            }

            "2" => {
                check viewByInstitution();
            }

            "3" => {
                check viewByCampus();
            }

            "4" => {
                check overdueDashboard();
            }

            "5" => {
                check viewAssetMaintenance();
            }

            "6" => {
                check addMaintenanceSchedule();
            }

            "7" => {
                check deleteMaintenanceSchedule();
            }

            "8" => {
                check viewAsset();
            }

            "9" => {
                check createAsset();
            }

            "10" => {
                check updateAsset();
            }

            "11" => {
                check deleteAsset();
            }

            "0" => {
                running = false;

                io:println("");
                io:println("Thank you for using the Ministry Library System.");
            }

            _ => {
                io:println("");
                io:println("Invalid option.");
            }
        }

        if running {
            io:println("");
            io:println("Press Enter to continue...");
            _ = io:readln();
        }
    }
}

