import Fluent
import Vapor

struct RegionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let regions = routes.grouped("region")
        regions.get(use: index)
        regions.post(use: create)
        regions.group(":regionID") { region in
            region.delete(use: delete)
        }
    }

    func index(req: Request) throws -> EventLoopFuture<[Region]> {
        return Region.query(on: req.db).all()
    }

    func create(req: Request) throws -> EventLoopFuture<Region> {
        let region = try req.content.decode(Region.self)
        return region.save(on: req.db).map { region }
    }

    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        return Region.find(req.parameters.get("regionID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .ok)
    }
}
