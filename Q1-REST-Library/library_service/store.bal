// THE DATABASE.
// A `table` with a declared key - not a plain map. The difference matters:
// `.add()` on a table FAILS if the key already exists, whereas a map would
// silently overwrite. For a "create" operation, silent overwrite is wrong.
table<Asset> key(assetTag) assetStore = table [];

// Return every asset.
public function listAssets() returns Asset[] {
    return assetStore.toArray();
}

// Look up one. Returns nil if there's no such tag.
public function getAsset(string assetTag) returns Asset? {
    return assetStore[assetTag];
}

// Seed some data so the service has something to show on startup.
public function seed() {
    assetStore.add({
        assetTag: "NUST-LIB-3DP-001",
        name: "Pro-Series 3D Printer",
        description: "High-precision laboratory printer for prototyping.",
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Innovation Lab",
        status: AVAILABLE,
        dateAcquired: "2024-03-10"
    });
    assetStore.add({
        assetTag: "NUST-LIB-LAP-014",
        name: "Dell Latitude 5440",
        description: "Student loan laptop.",
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Library",
        status: AVAILABLE,
        dateAcquired: "2025-01-20"
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
// Create. Returns an error if the tag is already taken.
public function addAsset(Asset asset) returns Asset|error {
    if assetStore.hasKey(asset.assetTag) {
        return error(string `Asset '${asset.assetTag}' already exists`);
    }
    assetStore.add(asset);
    return asset;
}

// Partial update. Only overwrites the fields the caller actually sent.
public function updateAsset(string assetTag, AssetUpdate patch) returns Asset|error {
    Asset? existing = assetStore[assetTag];
    if existing is () {
        return error(string `Asset '${assetTag}' not found`);
    }

    // `is string` narrows the optional field away. If the caller didn't send
    // `name`, patch.name is nil and we leave the stored value alone.
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

// Delete. Returns the removed asset so the caller can confirm what went.
public function removeAsset(string assetTag) returns Asset|error {
    Asset? removed = assetStore.removeIfHasKey(assetTag);
    if removed is () {
        return error(string `Asset '${assetTag}' not found`);
    }
    return removed;
}
