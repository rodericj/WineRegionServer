import Fluent

struct CreateRegion: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("region")
            .id()
            .field("title", .string, .required)
            .unique(on: "title")
            .field("url", .string, .required)
            .field("parent_id", .uuid, .references("region", "id", onDelete: .cascade))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("region").delete()
    }
}
