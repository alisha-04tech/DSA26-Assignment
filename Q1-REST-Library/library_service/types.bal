// The lifecycle of a library resource.
// OCCUPIED is for spaces (labs, meeting rooms); LOANED_OUT is for items.
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

public type Schedule record {|
    readonly string scheduleId;
    // `type` is a Ballerina keyword, so we write 'type with an apostrophe.
    // It still serialises to the JSON key "type", which is what the brief's
    // sample payload uses. Same escape hatch as the `conflict` problem.
    ScheduleType 'type;
    string dueDate;          // "YYYY-MM-DD"
    string description = "";
|};
public type Asset record {|
    readonly string assetTag;
    string name;
    string description = "";
    string institution;
    string site;
    AssetStatus status = AVAILABLE;
    string dateAcquired;
        Schedule[] schedules = [];
|};
// Partial-update payload for PUT. Every field optional, so a caller sends
// only what changed. assetTag is absent on purpose: identity lives in the
// URL, never in the body.
public type AssetUpdate record {|
    string name?;
    string description?;
    string institution?;
    string site?;
    AssetStatus status?;
    string dateAcquired?;
|};

// A consistent error shape, so the client only ever parses one format.
public type ErrorResponse record {|
    string message;
    string details = "";
|};
// What the overdue dashboard returns. Not an Asset - it's a different view,
// carrying the specific schedule that tripped the rule plus how late it is,
// so staff don't have to re-scan the asset to find out why it's listed.
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
// ask `if e is NotFoundError` instead of grepping the message text. The
// store raises a MEANING; the transport layer picks the wire representation.
public type NotFoundError distinct error;      // -> 404
public type ConflictError distinct error;      // -> 409  (valid request, wrong state)
public type ValidationError distinct error;    // -> 400  (malformed input)

public type LoanRequest record {|
    string borrowerId;
    string dueDate;
    ScheduleType 'type = BOOKING;
|};
