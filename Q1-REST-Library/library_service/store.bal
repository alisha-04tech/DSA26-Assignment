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
