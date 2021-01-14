import Fluent
import Vapor

struct CloudRegion: Content {
    let title: String
    let url: URL
    let children: [CloudRegion]?
}

extension CloudRegion {
    var region: Region {
        Region(title: title, url: url.absoluteString)
    }
}

struct RegionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let regions = routes.grouped("region")
        regions.get(use: index)
        regions.post(use: create)
        regions.group(":regionID") { region in
            region.delete(use: delete)
            region.put(use: attachChild)
        }
    }

    func index(req: Request) throws -> EventLoopFuture<[Region]> {
        return Region.query(on: req.db)
            .filter(\.$parent.$id == nil)
            .with(\.$children) { child in
                child.with(\.$children) { child in
                    child.with(\.$children) { child in
                        child.with(\.$children) { child in
                            child.with(\.$children) { child in
                                child.with(\.$children)
                            }
                        }
                    }
                }
            }
            .all()
    }

    func attachChild(req: Request) throws -> EventLoopFuture<Region> {
        let cloudRegion = try req.content.decode(CloudRegion.self)
        let newRegion = cloudRegion.region

        return Region.find(req.parameters.get("regionID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { foundRegion in
                foundRegion.$children.create(newRegion, on: req.db)
            }.map { newRegion }
    }

    func create(req: Request) throws -> EventLoopFuture<Region> {
        let cloudRegion = try req.content.decode(CloudRegion.self)
        let region = cloudRegion.region
        return region.save(on: req.db).map { region }
    }

    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        return Region.find(req.parameters.get("regionID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .ok)
    }
}
