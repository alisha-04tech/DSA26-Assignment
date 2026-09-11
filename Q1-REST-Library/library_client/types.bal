// ============================================================================
// types.bal (CLIENT side)
//
// TALKING POINT FOR THE PRESENTATION:
// These records DUPLICATE the ones in library_service. That is the central
// weakness of plain REST as an IPC mechanism: there is no machine-readable
// contract, so client and server each hand-maintain their own copy of the
// model and can silently DRIFT apart. Rename a field on the server and
// nothing breaks at compile time - it breaks at runtime, in front of a user.
//
// That is exactly the problem an IDL solves, and it is why Question 2 uses
// gRPC: there, ONE .proto file generates both the client stub and the server
// skeleton, so drift becomes a compile error. We built both so we could show
// the contrast. (Week 3: "Service Contracts and IDLs".)
//
// Mitigation used here: these are OPEN records (`record { }`, no bars), so
// the client tolerates the server ADDING fields. It only breaks if the server
// REMOVES or renames one - the same forwards-compatibility rule protobuf
// gives you for free.
// ============================================================================

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

public type Component record {
    string compId;
    string name;
    string description = "";
};

public type Schedule record {
    string scheduleId;
    ScheduleType 'type;
    string dueDate;
    string description = "";
};

public type Task record {
    string taskId;
    string description;
    boolean done = false;
};

public type WorkOrder record {
    string orderId;
    WorkOrderStatus status = OPEN;
    string description;
    Task[] tasks = [];
};

public type Asset record {
    string assetTag;
    string name;
    string description = "";
    string institution;
    string site;
    AssetStatus status = AVAILABLE;
    string dateAcquired;
    Component[] components = [];
    Schedule[] schedules = [];
    WorkOrder[] workOrders = [];
};

public type Institution record {
    string code;
    string name;
    string[] sites = [];
};

public type OverdueEntry record {
    string assetTag;
    string name;
    string institution;
    string site;
    AssetStatus status;
    Schedule overdueSchedule;
    int daysOverdue;
};

public type LoanBody record {
    string borrowerId;
    string dueDate;
    ScheduleType 'type;
};
