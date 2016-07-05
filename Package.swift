import PackageDescription

let package = Package(
    name: "Vapor",
    dependencies: [
        //Standards package. Contains protocols for cross-project compatability.
        .Package(url: "./LocalPackages/S4", Version(0,0,0)),

        //Parses and serializes JSON - using fork until update core library
        .Package(url: "./LocalPackages/Jay", Version(0,0,0)),

        //SHA2 + HMAC hashing. Used by the core to create session identifiers.
        .Package(url: "./LocalPackages/HMAC", Version(0,0,0)),
        .Package(url: "./LocalPackages/SHA2", Version(0,0,0)),

        //Websockets
        .Package(url: "./LocalPackages/SHA1", Version(0,0,0)),

        //ORM for interacting with databases
        .Package(url: "./LocalPackages/Fluent", Version(0,0,0)),

        //Allows complex key path subscripts
        .Package(url: "./LocalPackages/PathIndexable", Version(0,0,0)),

        //Sockets, used by the built in HTTP server
        .Package(url: "./LocalPackages/Socks", Version(0,0,0)),

        // Syntax for easily accessing values from generic data.
        .Package(url: "./LocalPackages/Polymorphic", Version(0,0,0)),

        // libc
        .Package(url: "./LocalPackages/libc", Version(0,0,0)),
    ],
    exclude: [
        "XcodeProject",
        "Generator",
        "Development"
    ],
    targets: [
        Target(
            name: "Vapor"
        ),
        Target(
            name: "Development",
            dependencies: [
                .Target(name: "Vapor")
            ]
        ),
        Target(
            name: "Performance",
            dependencies: [
                .Target(name: "Vapor")
            ]
        ),
        Target(
            name: "Generator"
        )
    ]
)
