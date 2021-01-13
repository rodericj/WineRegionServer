import Fluent

struct CreateRegion: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("region")
            .id()
            .field("title", .string, .required)
            .field("url", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("region").delete()
    }
}
