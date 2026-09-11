// ============================================================================
// client.bal  -  Command-line client for the Library Management API
//
// Covers the five capabilities the brief requires:
//   1. Loaning & Booking      (menu 5 / 6)
//   2. Global View            (menu 1)
//   3. Campus View            (menu 2)
//   4. Overdue Dashboard      (menu 4)
//   5. Schedule Manager       (menu 7 / 8 / 9)
//
// RESILIENCY (Week 3, and the Week 2 lab's "Extra Exercise 1"):
// The http:Client is configured with a TIMEOUT and a bounded RETRY policy with
// exponential back-off. That is the practical answer to "what happens if the
// service is temporarily unreachable?" - the client does not hang forever, it
// fails fast and retries a limited number of times.
//
// Note the retry policy lists ONLY 502/503/504 - transient server-side faults.
// We deliberately do NOT retry 4xx: a 404 or 409 will still be a 404 or 409 on
// the second attempt, and blindly retrying a POST whose reply was merely lost
// would create a duplicate. That is the at-least-once vs at-most-once
// trade-off from Week 3, made concrete in configuration.
// ============================================================================

import ballerina/http;
import ballerina/io;

configurable string baseUrl = "http://localhost:9090";

final http:Client libClient = check new (baseUrl, {
    timeout: 10,
    retryConfig: {
        count: 3,
        interval: 1,
        backOffFactor: 2.0,
        maxWaitInterval: 8,
        statusCodes: [502, 503, 504]
    }
});

const string LINE = "--------------------------------------------------------------------------";

function header(string title) {
    io:println("\n" + LINE);
    io:println("  " + title);
    io:println(LINE);
}

function pad(string s, int width) returns string {
    string out = s;
    if out.length() > width {
        return out.substring(0, width - 1) + "~";
    }
    while out.length() < width {
        out += " ";
    }
    return out;
}

function ask(string prompt) returns string {
    return io:readln(prompt).trim();
}

function report(error e) {
    io:println("  ! " + e.message());
}

function printAssetTable(Asset[] assets) {
    if assets.length() == 0 {
        io:println("  (no assets matched)");
        return;
    }
    io:println("  " + pad("ASSET TAG", 20) + pad("NAME", 30) + pad("SITE", 30) + "STATUS");
    io:println("  " + LINE);
    foreach Asset a in assets {
        io:println("  " + pad(a.assetTag, 20) + pad(a.name, 30) + pad(a.site, 30) + a.status);
    }
    io:println(string `  ${assets.length()} asset(s).`);
}

// ---------------------------------------------------------------------------
// 1. GLOBAL VIEW
// ---------------------------------------------------------------------------
function globalView() {
    header("GLOBAL VIEW - all assets across the Ministry");
    Asset[]|error result = libClient->get("/library/assets");
    if result is error {
        report(result);
        return;
    }
    printAssetTable(result);
}

// ---------------------------------------------------------------------------
// 2. CAMPUS VIEW
// ---------------------------------------------------------------------------
// Uses the institution CODE (NUST, UNAM) rather than the full name, so there
// are no spaces to percent-encode in the URL.
function campusView() {
    header("CAMPUS VIEW - filter by institution / site");

    Institution[]|error insts = libClient->get("/library/institutions");
    if insts is error {
        report(insts);
        return;
    }
    io:println("  Known institutions:");
    foreach Institution i in insts {
        io:println(string `    ${pad(i.code, 8)} ${i.name}`);
        foreach string s in i.sites {
            io:println(string `             site: ${s}`);
        }
    }

    string code = ask("\n  Institution code (e.g. NUST): ");
    Asset[]|error result = libClient->get(string `/library/institutions/${code}/assets`);
    if result is error {
        report(result);
        return;
    }
    printAssetTable(result);
}

// ---------------------------------------------------------------------------
// 3. ASSET DETAIL
// ---------------------------------------------------------------------------
function inspectAsset() {
    header("ASSET DETAIL");
    string tag = ask("  Asset tag: ");
    Asset|error result = libClient->get(string `/library/assets/${tag}`);
    if result is error {
        report(result);
        return;
    }
    io:println(result.toJsonString());
}

// ---------------------------------------------------------------------------
// 4. OVERDUE DASHBOARD
// ---------------------------------------------------------------------------
function overdueDashboard() {
    header("OVERDUE DASHBOARD");
    OverdueEntry[]|error result = libClient->get("/library/overdue");
    if result is error {
        report(result);
        return;
    }
    if result.length() == 0 {
        io:println("  Nothing overdue.");
        return;
    }
    io:println("  " + pad("ASSET TAG", 20) + pad("SCHEDULE", 12) + pad("DUE", 12) +
               pad("DAYS LATE", 11) + "DESCRIPTION");
    io:println("  " + LINE);
    foreach OverdueEntry e in result {
        io:println("  " + pad(e.assetTag, 20) + pad(e.overdueSchedule.scheduleId, 12) +
                   pad(e.overdueSchedule.dueDate, 12) + pad(e.daysOverdue.toString(), 11) +
                   e.overdueSchedule.description);
    }
    io:println(string `  ${result.length()} overdue item(s).`);
}

// ---------------------------------------------------------------------------
// 5. LOAN / BOOK
// ---------------------------------------------------------------------------
function loanOrBook() {
    header("LOAN AN ASSET / BOOK A SPACE");
    string tag = ask("  Asset tag: ");
    string kind = ask("  (B)ooking for a room, or (L)oan for an item [B/L]: ");
    string borrower = ask("  Borrower / student number: ");
    string due = ask("  Due date (YYYY-MM-DD): ");

    LoanBody body = {
        borrowerId: borrower,
        dueDate: due,
        'type: kind.toUpperAscii().startsWith("L") ? LOAN : BOOKING
    };

    Asset|error result = libClient->post(string `/library/assets/${tag}/loan`, body);
    if result is error {
        report(result);
        return;
    }
    io:println(string `  OK - '${result.name}' is now ${result.status}, due ${due}.`);
}

// ---------------------------------------------------------------------------
// 6. CHECK IN
// ---------------------------------------------------------------------------
function checkIn() {
    header("RETURN AN ASSET");
    string tag = ask("  Asset tag: ");
    Asset|error result = libClient->post(string `/library/assets/${tag}/checkin`, {});
    if result is error {
        report(result);
        return;
    }
    io:println(string `  OK - '${result.name}' is back to ${result.status}.`);
}

// ---------------------------------------------------------------------------
// 7/8/9. SCHEDULE MANAGER
// ---------------------------------------------------------------------------
function viewSchedules() {
    header("SCHEDULES FOR AN ASSET");
    string tag = ask("  Asset tag: ");
    Schedule[]|error result = libClient->get(string `/library/assets/${tag}/schedules`);
    if result is error {
        report(result);
        return;
    }
    if result.length() == 0 {
        io:println("  (no schedules)");
        return;
    }
    io:println("  " + pad("ID", 16) + pad("TYPE", 14) + pad("DUE", 12) + "DESCRIPTION");
    io:println("  " + LINE);
    foreach Schedule s in result {
        io:println("  " + pad(s.scheduleId, 16) + pad(s.'type, 14) + pad(s.dueDate, 12) + s.description);
    }
}

function addSchedule() {
    header("ADD A SERVICING SCHEDULE");
    string tag = ask("  Asset tag: ");
    string id = ask("  Schedule ID (e.g. SCH-900): ");
    string kindRaw = ask("  Type [MAINTENANCE / SERVICING]: ");
    string due = ask("  Due date (YYYY-MM-DD): ");
    string desc = ask("  Description: ");

    ScheduleType kind = kindRaw.toUpperAscii() == "SERVICING" ? SERVICING : MAINTENANCE;

    Schedule payload = {scheduleId: id, 'type: kind, dueDate: due, description: desc};
    Schedule|error result = libClient->post(string `/library/assets/${tag}/schedules`, payload);
    if result is error {
        report(result);
        return;
    }
    io:println(string `  OK - schedule ${result.scheduleId} added, due ${result.dueDate}.`);
}

function removeSchedule() {
    header("REMOVE A SCHEDULE");
    string tag = ask("  Asset tag: ");
    string id = ask("  Schedule ID: ");
    Schedule|error result = libClient->delete(string `/library/assets/${tag}/schedules/${id}`);
    if result is error {
        report(result);
        return;
    }
    io:println(string `  OK - removed ${result.scheduleId}.`);
}

// ---------------------------------------------------------------------------
// 10/11. ASSET ADMIN
// ---------------------------------------------------------------------------
function createAsset() {
    header("REGISTER A NEW ASSET");
    Asset payload = {
        assetTag: ask("  Asset tag (unique): "),
        name: ask("  Name: "),
        description: ask("  Description: "),
        institution: ask("  Institution (full name): "),
        site: ask("  Site / campus: "),
        dateAcquired: ask("  Date acquired (YYYY-MM-DD): "),
        status: AVAILABLE
    };
    Asset|error result = libClient->post("/library/assets", payload);
    if result is error {
        report(result);
        return;
    }
    io:println(string `  OK - created ${result.assetTag}.`);
}

function deleteAsset() {
    header("DELETE AN ASSET");
    string tag = ask("  Asset tag: ");
    if ask(string `  Really delete '${tag}'? [y/N]: `).toLowerAscii() != "y" {
        io:println("  Cancelled.");
        return;
    }
    Asset|error result = libClient->delete(string `/library/assets/${tag}`);
    if result is error {
        report(result);
        return;
    }
    io:println(string `  OK - deleted ${result.assetTag}.`);
}

// ---------------------------------------------------------------------------
// 12. INSTITUTIONS
// ---------------------------------------------------------------------------
function manageInstitutions() {
    header("MANAGE INSTITUTIONS");
    io:println("  (l)ist   (a)dd   (r)emove");
    string op = ask("  Choose: ").toLowerAscii();

    if op == "l" {
        Institution[]|error insts = libClient->get("/library/institutions");
        if insts is error {
            report(insts);
            return;
        }
        foreach Institution i in insts {
            io:println(string `    ${pad(i.code, 8)} ${i.name}  (${i.sites.length()} site(s))`);
        }
        return;
    }

    if op == "a" {
        Institution payload = {
            code: ask("  Code (e.g. IUM): "),
            name: ask("  Full name: "),
            sites: []
        };
        Institution|error result = libClient->post("/library/institutions", payload);
        if result is error {
            report(result);
            return;
        }
        io:println(string `  OK - added ${result.code}.`);
        return;
    }

    if op == "r" {
        string code = ask("  Code to remove: ");
        Institution|error result = libClient->delete(string `/library/institutions/${code}`);
        if result is error {
            report(result);
            return;
        }
        io:println(string `  OK - removed ${result.code}.`);
        return;
    }

    io:println("  Unknown option.");
}

// ---------------------------------------------------------------------------
// 13. WORK ORDERS
// ---------------------------------------------------------------------------
function manageWorkOrders() {
    header("WORK ORDERS");
    io:println("  (o)pen a work order   (c)lose a work order   (t)ask add");
    string op = ask("  Choose: ").toLowerAscii();
    string tag = ask("  Asset tag: ");

    if op == "o" {
        WorkOrder payload = {
            orderId: ask("  Work order ID (e.g. WO-900): "),
            description: ask("  Fault description: "),
            status: OPEN,
            tasks: []
        };
        WorkOrder|error result = libClient->post(string `/library/assets/${tag}/workorders`, payload);
        if result is error {
            report(result);
            return;
        }
        io:println(string `  OK - opened ${result.orderId}; asset moved to UNDER_MAINTENANCE.`);
        return;
    }

    if op == "c" {
        string id = ask("  Work order ID: ");
        WorkOrder|error result = libClient->put(
            string `/library/assets/${tag}/workorders/${id}`, {status: "CLOSED"});
        if result is error {
            report(result);
            return;
        }
        io:println(string `  OK - ${result.orderId} is now ${result.status}.`);
        return;
    }

    if op == "t" {
        string id = ask("  Work order ID: ");
        Task payload = {
            taskId: ask("  Task ID (e.g. T2): "),
            description: ask("  Task description: ")
        };
        Task|error result = libClient->post(
            string `/library/assets/${tag}/workorders/${id}/tasks`, payload);
        if result is error {
            report(result);
            return;
        }
        io:println(string `  OK - added task ${result.taskId}.`);
        return;
    }

    io:println("  Unknown option.");
}

// ---------------------------------------------------------------------------
// MENU
// ---------------------------------------------------------------------------
function printMenu() {
    io:println("\n" + LINE);
    io:println("  MINISTRY OF HIGHER EDUCATION - LIBRARY & RESOURCE MANAGEMENT");
    io:println("  connected to: " + baseUrl);
    io:println(LINE);
    io:println("   1) Global view - all assets");
    io:println("   2) Campus view - filter by institution");
    io:println("   3) Asset detail");
    io:println("   4) Overdue dashboard");
    io:println("   5) Loan an asset / book a space");
    io:println("   6) Return an asset");
    io:println("   7) View schedules for an asset");
    io:println("   8) Add a servicing schedule");
    io:println("   9) Remove a schedule");
    io:println("  10) Register a new asset");
    io:println("  11) Delete an asset");
    io:println("  12) Manage institutions");
    io:println("  13) Work orders");
    io:println("   0) Quit");
}

public function main() returns error? {
    // Fail fast with a friendly message if the service is not running, rather
    // than letting every menu option blow up one at a time.
    json|error health = libClient->get("/library/health");
    if health is error {
        io:println("Cannot reach the library service at " + baseUrl);
        io:println("Start it first:  bal run library_service");
        return;
    }
    io:println("Connected. Service reports: " + health.toJsonString());

    while true {
        printMenu();
        string choice = ask("\n  Select: ");
        match choice {
            "1" => {
                globalView();
            }
            "2" => {
                campusView();
            }
            "3" => {
                inspectAsset();
            }
            "4" => {
                overdueDashboard();
            }
            "5" => {
                loanOrBook();
            }
            "6" => {
                checkIn();
            }
            "7" => {
                viewSchedules();
            }
            "8" => {
                addSchedule();
            }
            "9" => {
                removeSchedule();
            }
            "10" => {
                createAsset();
            }
            "11" => {
                deleteAsset();
            }
            "12" => {
                manageInstitutions();
            }
            "13" => {
                manageWorkOrders();
            }
            "0" => {
                io:println("Goodbye.");
                return;
            }
            _ => {
                io:println("  Unknown option.");
            }
        }
    }
}
