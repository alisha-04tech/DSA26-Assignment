// The lifecycle of a library resource.
// OCCUPIED is for spaces (labs, meeting rooms); LOANED_OUT is for items.
public enum AssetStatus {
    AVAILABLE,
    LOANED_OUT,
    OCCUPIED,
    UNDER_MAINTENANCE,
    DISPOSED
}

public type Asset record {|
    readonly string assetTag;
    string name;
    string description = "";
    string institution;
    string site;
    AssetStatus status = AVAILABLE;
    string dateAcquired;
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
