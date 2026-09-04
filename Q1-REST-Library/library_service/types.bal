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
