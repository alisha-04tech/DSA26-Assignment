type AssetStatus "AVAILABLE"|"LOANED_OUT"|"OCCUPIED"|"UNDER_MAINTENANCE"|"DISPOSED";

type Component record {|
    string compId;
    string name;
    string description;
|};

public type Schedule record {|
    string scheduleId;
    string scheduleType;
    string dueDate;
    string description;
|};

public type WorkTask record {|
    string taskId;
    string description;
|};

public type WorkOrder record {|
    string orderId;
    string status;
    string description;
    WorkTask[] tasks = [];
|};

type Asset record {|
    readonly string assetTag;
    string name;
    string description;
    string institution;
    string site;
    AssetStatus status;
    string dateAcquired;
    Component[] components = [];
    Schedule[] schedules = [];
    WorkOrder[] workOrders = [];
|};

public type OverdueAsset record {|
    string assetTag;
    string name;
    string institution;
    string site;
    string scheduleId;
    string scheduleType;
    string dueDate;
    string description;
|};