public enum AssetStatus {
    AVAILABLE,
    LOANED_OUT,
    OCCUPIED,
    UNDER_MAINTENANCE,
    DISPOSED
}

public enum ScheduleType {
    MAINTENANCE,
    BOOKING,
    SERVICING,
    LOAN
}

public enum WorkOrderStatus {
    OPEN,
    IN_PROGRESS,
    CLOSED
}

// A replaceable part of a complex asset (e.g. a printer's stepper motor).
public type Component record {|
    readonly string compId;
    string name;
    string description = "";
|};

public type Schedule record {|
    readonly string scheduleId;
    // 'type escapes the Ballerina keyword; serialises as "type" on the wire.
    ScheduleType 'type;
    string dueDate;
    string description = "";
|};

// A unit of repair work inside a work order, e.g. "replace screen".
public type Task record {|
    readonly string taskId;
    string description;
    boolean done = false;
|};

public type WorkOrder record {|
    readonly string orderId;
    WorkOrderStatus status = OPEN;
    string description;
    Task[] tasks = [];
|};

public type Asset record {|
    readonly string assetTag;
    string name;
    string description = "";
    string institution;
    string site;
    AssetStatus status = AVAILABLE;
    string dateAcquired;
    Component[] components = [];
    Schedule[] schedules = [];
    WorkOrder[] workOrders = [];
|};

public type AssetUpdate record {|
    string name?;
    string description?;
    string institution?;
    string site?;
    AssetStatus status?;
    string dateAcquired?;
|};

// Institution registry. Assets carry the full name (the brief's payload
// format), but the registry holds it once with a short code, and filters
// accept either - so "NUST" and the full legal name both work.
public type Institution record {|
    readonly string code;
    string name;
    string[] sites = [];
|};

public type InstitutionUpdate record {|
    string name?;
    string[] sites?;
|};

public type LoanRequest record {|
    string borrowerId;
    string dueDate;
    ScheduleType 'type = BOOKING;
|};

public type ErrorResponse record {|
    string message;
    string details = "";
|};

public type OverdueEntry record {|
    string assetTag;
    string name;
    string institution;
    string site;
    AssetStatus status;
    Schedule overdueSchedule;
    int daysOverdue;
|};

// `distinct` gives each error its own TYPE identity, so the HTTP layer can
// ask `if e is NotFoundError` instead of grepping the message text.
public type NotFoundError distinct error;
public type ConflictError distinct error;
public type ValidationError distinct error;
