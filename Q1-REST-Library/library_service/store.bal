import ballerina/time;

// ============================================================================
// THE DATABASE
// ============================================================================
// A `table` with a declared key, not a plain map. `.add()` FAILS on a
// duplicate key where a map would silently overwrite - and silent overwrite
// is the wrong behaviour for a create operation.
table<Asset> key(assetTag) assetStore = table [];
table<Institution> key(code) institutionStore = table [];

// ============================================================================
// ASSET OPERATIONS
// ============================================================================

public function listAssets() returns Asset[] {
    return assetStore.toArray();
}

public function getAsset(string assetTag) returns Asset? {
    return assetStore[assetTag];
}

public function addAsset(Asset asset) returns Asset|error {
    if assetStore.hasKey(asset.assetTag) {
        return error ConflictError(string `Asset '${asset.assetTag}' already exists`);
    }
    assetStore.add(asset);
    return asset;
}

// Partial update: only overwrites the fields the caller actually sent.
public function updateAsset(string assetTag, AssetUpdate patch) returns Asset|error {
    Asset? existing = assetStore[assetTag];
    if existing is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }

    // `is string` narrows the optional away. Absent field -> leave alone.
    string? nm = patch.name;
    if nm is string {
        existing.name = nm;
    }
    string? ds = patch.description;
    if ds is string {
        existing.description = ds;
    }
    string? inst = patch.institution;
    if inst is string {
        existing.institution = inst;
    }
    string? st = patch.site;
    if st is string {
        existing.site = st;
    }
    AssetStatus? stat = patch.status;
    if stat is AssetStatus {
        existing.status = stat;
    }
    string? da = patch.dateAcquired;
    if da is string {
        existing.dateAcquired = da;
    }
    return existing;
}

public function removeAsset(string assetTag) returns Asset|error {
    Asset? removed = assetStore.removeIfHasKey(assetTag);
    if removed is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    return removed;
}

// ============================================================================
// FILTERING
// ============================================================================

function equalsIgnoreCase(string a, string b) returns boolean {
    return a.toLowerAscii() == b.toLowerAscii();
}

// Both filters optional: neither = everything. One function serves
// "all assets", "all NUST assets", and "all NUST assets at the Library".
public function filterAssets(string? institution, string? site) returns Asset[] {
    Asset[] result = [];
    foreach Asset a in assetStore {
        if institution is string && !equalsIgnoreCase(a.institution, institution) {
            continue;
        }
        if site is string && !equalsIgnoreCase(a.site, site) {
            continue;
        }
        result.push(a);
    }
    return result;
}

// ============================================================================
// SCHEDULES
// ============================================================================

public function getSchedules(string assetTag) returns Schedule[]|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    return a.schedules;
}

public function addSchedule(string assetTag, Schedule s) returns Schedule|error {
    // Validate the date before mutating anything.
    int _ = check toDayNumber(s.dueDate);

    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    foreach Schedule existing in a.schedules {
        if existing.scheduleId == s.scheduleId {
            return error ConflictError(string `Schedule '${s.scheduleId}' already exists`);
        }
    }
    a.schedules.push(s);
    return s;
}

public function removeSchedule(string assetTag, string scheduleId) returns Schedule|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    int idx = 0;
    foreach Schedule s in a.schedules {
        if s.scheduleId == scheduleId {
            return a.schedules.remove(idx);
        }
        idx += 1;
    }
    return error NotFoundError(string `Schedule '${scheduleId}' not found on '${assetTag}'`);
}

// ============================================================================
// DATE HELPERS
// ============================================================================
// Calendar dates only - no timezones. We convert to "days since 1970-01-01"
// so comparison and subtraction are plain integer arithmetic. The
// days-from-civil algorithm handles leap years including the century rule.

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

public function today() returns string {
    time:Civil c = time:utcToCivil(time:utcNow());
    return string `${c.year}-${pad2(c.month)}-${pad2(c.day)}`;
}

// ============================================================================
// OVERDUE CHECK
// ============================================================================

public function findOverdue(string? institution) returns OverdueEntry[]|error {
    int todayNum = check toDayNumber(today());
    Asset[] candidates = filterAssets(institution, ());
    OverdueEntry[] out = [];

    foreach Asset a in candidates {
        if a.status == DISPOSED {
            continue;
        }
        foreach Schedule s in a.schedules {
            int|error dueNum = toDayNumber(s.dueDate);
            if dueNum is error {
                // One malformed stored date must not sink the whole dashboard.
                continue;
            }
            if dueNum < todayNum {
                out.push({
                    assetTag: a.assetTag,
                    name: a.name,
                    institution: a.institution,
                    site: a.site,
                    status: a.status,
                    overdueSchedule: s,
                    daysOverdue: todayNum - dueNum
                });
            }
        }
    }
    return out;
}

// ============================================================================
// LOANING & BOOKING
// ============================================================================

public function loanAsset(string assetTag, LoanRequest req) returns Asset|error {
    // Validate the date BEFORE touching state - fail fast.
    int _ = check toDayNumber(req.dueDate);

    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    if a.status != AVAILABLE {
        return error ConflictError(
            string `Asset '${assetTag}' is ${a.status}, cannot be loaned`);
    }
    // Booking a room makes it OCCUPIED; loaning an item makes it LOANED_OUT.
    a.status = req.'type == BOOKING ? OCCUPIED : LOANED_OUT;
    a.schedules.push({
        scheduleId: string `LN-${assetTag}-${a.schedules.length() + 1}`,
        'type: req.'type,
        dueDate: req.dueDate,
        description: string `Held by ${req.borrowerId}, due ${req.dueDate}`
    });
    return a;
}

public function returnAsset(string assetTag) returns Asset|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    if a.status != LOANED_OUT && a.status != OCCUPIED {
        return error ConflictError(
            string `Asset '${assetTag}' is not on loan (status ${a.status})`);
    }
    a.status = AVAILABLE;

    // Drop the LOAN/BOOKING schedules. The item is back, so it must stop
    // appearing on the overdue dashboard. MAINTENANCE and SERVICING
    // schedules stay - those are still genuinely due.
    Schedule[] kept = [];
    foreach Schedule s in a.schedules {
        if s.'type != LOAN && s.'type != BOOKING {
            kept.push(s);
        }
    }
    a.schedules = kept;
    return a;
}

// ============================================================================
// COMPONENTS
// ============================================================================

public function addComponent(string assetTag, Component c) returns Component|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    foreach Component existing in a.components {
        if existing.compId == c.compId {
            return error ConflictError(
                string `Component '${c.compId}' already exists on '${assetTag}'`);
        }
    }
    a.components.push(c);
    return c;
}

public function removeComponent(string assetTag, string compId) returns Component|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    int idx = 0;
    foreach Component c in a.components {
        if c.compId == compId {
            return a.components.remove(idx);
        }
        idx += 1;
    }
    return error NotFoundError(string `Component '${compId}' not found on '${assetTag}'`);
}

// ============================================================================
// WORK ORDERS
// ============================================================================

public function openWorkOrder(string assetTag, WorkOrder wo) returns WorkOrder|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    foreach WorkOrder existing in a.workOrders {
        if existing.orderId == wo.orderId {
            return error ConflictError(string `Work order '${wo.orderId}' already exists`);
        }
    }
    a.workOrders.push(wo);
    // Raising a work order takes the asset out of service.
    if a.status == AVAILABLE {
        a.status = UNDER_MAINTENANCE;
    }
    return wo;
}

public function setWorkOrderStatus(string assetTag, string orderId, WorkOrderStatus st)
        returns WorkOrder|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    foreach WorkOrder wo in a.workOrders {
        if wo.orderId == orderId {
            wo.status = st;
            if st == CLOSED {
                // Back into service only when NOTHING is still open.
                boolean anyOpen = false;
                foreach WorkOrder w in a.workOrders {
                    if w.status != CLOSED {
                        anyOpen = true;
                    }
                }
                if !anyOpen && a.status == UNDER_MAINTENANCE {
                    a.status = AVAILABLE;
                }
            }
            return wo;
        }
    }
    return error NotFoundError(string `Work order '${orderId}' not found on '${assetTag}'`);
}

public function addTask(string assetTag, string orderId, Task t) returns Task|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    foreach WorkOrder wo in a.workOrders {
        if wo.orderId == orderId {
            foreach Task existing in wo.tasks {
                if existing.taskId == t.taskId {
                    return error ConflictError(string `Task '${t.taskId}' already exists`);
                }
            }
            wo.tasks.push(t);
            return t;
        }
    }
    return error NotFoundError(string `Work order '${orderId}' not found on '${assetTag}'`);
}

public function removeTask(string assetTag, string orderId, string taskId) returns Task|error {
    Asset? a = assetStore[assetTag];
    if a is () {
        return error NotFoundError(string `Asset '${assetTag}' not found`);
    }
    foreach WorkOrder wo in a.workOrders {
        if wo.orderId == orderId {
            int idx = 0;
            foreach Task t in wo.tasks {
                if t.taskId == taskId {
                    return wo.tasks.remove(idx);
                }
                idx += 1;
            }
            return error NotFoundError(string `Task '${taskId}' not found`);
        }
    }
    return error NotFoundError(string `Work order '${orderId}' not found on '${assetTag}'`);
}

// ============================================================================
// INSTITUTIONS
// ============================================================================

public function listInstitutions() returns Institution[] {
    return institutionStore.toArray();
}

public function addInstitution(Institution inst) returns Institution|error {
    if institutionStore.hasKey(inst.code) {
        return error ConflictError(string `Institution '${inst.code}' already exists`);
    }
    institutionStore.add(inst);
    return inst;
}

public function updateInstitution(string code, InstitutionUpdate patch)
        returns Institution|error {
    Institution? inst = institutionStore[code];
    if inst is () {
        return error NotFoundError(string `Institution '${code}' not found`);
    }
    string? nm = patch.name;
    if nm is string {
        inst.name = nm;
    }
    string[]? sites = patch.sites;
    if sites is string[] {
        inst.sites = sites;
    }
    return inst;
}

// REFERENTIAL INTEGRITY: refuse to delete an institution that still owns
// assets. Silently orphaning rows is how distributed systems rot.
public function removeInstitution(string code) returns Institution|error {
    Institution? inst = institutionStore[code];
    if inst is () {
        return error NotFoundError(string `Institution '${code}' not found`);
    }
    int owned = 0;
    foreach Asset a in assetStore {
        if equalsIgnoreCase(a.institution, code) || equalsIgnoreCase(a.institution, inst.name) {
            owned += 1;
        }
    }
    if owned > 0 {
        return error ConflictError(
            string `Institution '${code}' still owns ${owned} asset(s); reassign or delete them first`);
    }
    return institutionStore.remove(code);
}

// Assets belonging to an institution, matched on EITHER code or full name.
public function assetsForInstitution(string code, string? site) returns Asset[]|error {
    Institution? inst = institutionStore[code];
    if inst is () {
        return error NotFoundError(string `Institution '${code}' not found`);
    }
    Asset[] result = [];
    foreach Asset a in assetStore {
        boolean matches = equalsIgnoreCase(a.institution, code)
            || equalsIgnoreCase(a.institution, inst.name);
        if !matches {
            continue;
        }
        if site is string && !equalsIgnoreCase(a.site, site) {
            continue;
        }
        result.push(a);
    }
    return result;
}

// ============================================================================
// SEED DATA
// ============================================================================

public function seedInstitutions() {
    institutionStore.add({
        code: "NUST",
        name: "Namibia University of Science and Technology",
        sites: ["Main Campus - Innovation Lab", "Main Campus - Library", "Ongwediva Campus"]
    });
    institutionStore.add({
        code: "UNAM",
        name: "University of Namibia",
        sites: ["Main Campus", "Oshakati Campus"]
    });
}

public function seed() {
    assetStore.add({
        assetTag: "NUST-LIB-3DP-001",
        name: "Pro-Series 3D Printer",
        description: "High-precision laboratory printer for prototyping.",
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Innovation Lab",
        status: AVAILABLE,
        dateAcquired: "2024-03-10",
        components: [
            {
                compId: "C101",
                name: "High-Torque Stepper Motor",
                description: "Main motor for X-axis movement."
            }
        ],
        schedules: [
            {
                scheduleId: "SCH-882",
                'type: MAINTENANCE,
                dueDate: "2026-09-01",
                description: "Quarterly calibration and nozzle cleaning."
            }
        ]
    });
    assetStore.add({
        assetTag: "NUST-LIB-LAP-014",
        name: "Dell Latitude 5440",
        description: "Student loan laptop.",
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Library",
        status: AVAILABLE,
        dateAcquired: "2025-01-20",
        schedules: [
            {
                scheduleId: "SCH-101",
                'type: MAINTENANCE,
                dueDate: "2026-07-01",
                description: "Annual OS re-image - deliberately overdue for testing."
            }
        ]
    });
    assetStore.add({
        assetTag: "NUST-MTG-ROOM-02",
        name: "Innovation Lab Meeting Room 2",
        description: "12-seat bookable meeting space.",
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Innovation Lab",
        status: AVAILABLE,
        dateAcquired: "2023-08-01"
    });
    assetStore.add({
        assetTag: "UNAM-LIB-TC-207",
        name: "HP Thin Client t640",
        description: "Library catalogue terminal.",
        institution: "University of Namibia",
        site: "Main Campus",
        status: UNDER_MAINTENANCE,
        dateAcquired: "2022-11-05"
    });
}
