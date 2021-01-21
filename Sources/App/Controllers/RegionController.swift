import Fluent
import Vapor
import PostgresNIO

struct CloudRegion: Content {
    let title: String
    let url: URL?
    let children: [CloudRegion]?
    let isPassthrough: Bool?
}

extension CloudRegion {
    var region: Region {
        Region(title: title, url: url?.absoluteString, isPassthrough: isPassthrough ?? false)
    }
}

enum RegionError: Error {
    case invalidRegionNoURL
}

struct CloudRegionLocationName: Content {
    let name: String
}

struct RegionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let regions = routes.grouped("region")
        regions.get(use: index)
        regions.post(use: create)
//        regions.post("fetch", use: fetch)
        regions.group(":regionID") { region in
            region.delete(use: delete)
            region.group("add") { newAttachedRegion in
                newAttachedRegion.post(use: attachChild)
            }
            region.group("create") { newAttachedRegion in
                newAttachedRegion.post(use: createChildByHittingOpenStreetMaps)
            }
            region.get("geojson", use: geoJson)
        }
    }

    /// GET: /region/
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

    /// POST: /region/XYZ-ABC-123/add
    func attachChild(req: Request) throws -> EventLoopFuture<Region> {
        let cloudRegion = try req.content.decode(CloudRegion.self)
        let newRegion = cloudRegion.region

        return Region.find(req.parameters.get("regionID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { foundRegion in
                foundRegion.$children.create(newRegion, on: req.db)
                    .flatMapError { (error) -> EventLoopFuture<Void> in
                        if let pgerror = error as? PostgresNIO.PostgresError {
                            switch pgerror.code {
                            case PostgresNIO.PostgresError.Code.uniqueViolation:
                                return req.eventLoop.future(error: Abort(.notAcceptable, reason: pgerror.errorDescription))
                            default:
                                break
                            }
                        }
                        return req.eventLoop.future(error: error)
                    }
            }.map { newRegion }
    }

    /// GET: /region/XYZ-ABC-123/geojson
    func geoJson(req: Request) throws -> EventLoopFuture<ClientResponse> {
        print(req)
        return Region.find(req.parameters.get("regionID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { foundRegion in
                // Ok so we know what the region is, now we can check if it is a passthrough
                if foundRegion.isPassthrough {
                    let urlString = "http://127.0.0.1:5000/"
                    let uri = URI(string: urlString)
                    return req.client.post(uri) { req in
                        // Encode JSON to the request body.
                        try req.content.encode(["name": foundRegion.title])
                    }.map { response in
                        print(response)
                        return response
                    }
                } else if let url = foundRegion.url {
                    let githubURI = URI(string: url)
                    return req.client.get(githubURI).map { response in
                        print(response)
                        return response
                    }
                } else {
                    return req.eventLoop.future(error: RegionError.invalidRegionNoURL)
                }
            }
    }

    /// POST: /region/XYZ-ABC-123/create
    func createChildByHittingOpenStreetMaps(req: Request) throws -> EventLoopFuture<Region> {
        let cloudRegion = try req.content.decode(CloudRegionLocationName.self)
        let title = cloudRegion.name
        let thisServerHostName = "http://localhost:8080"
        let newRegion = Region(title: title, url: "\(thisServerHostName)/region/", isPassthrough: true)

        return Region.find(req.parameters.get("regionID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { foundRegion in
                do {
                    return try fetch(req: req).flatMap { response in
                        foundRegion.$children.create(newRegion, on: req.db)
                            .flatMapError { (error) -> EventLoopFuture<Void> in
                                if let pgerror = error as? PostgresNIO.PostgresError {
                                    switch pgerror.code {
                                    case PostgresNIO.PostgresError.Code.uniqueViolation:
                                        return req.eventLoop.future(error: Abort(.notAcceptable, reason: pgerror.errorDescription))
                                    default:
                                        break
                                    }
                                }
                                return req.eventLoop.future(error: error)
                            }
                    }
                } catch {
                    return req.eventLoop.future(error: error)
                }
            }.map { newRegion }
    }

    private func fetch(req: Request) throws -> EventLoopFuture<ClientResponse> {
        let name = try req.content.decode(CloudRegionLocationName.self).name

        let urlString = "http://127.0.0.1:5000/"
        let uri = URI(string: urlString)
        return req.client.post(uri) { req in
            // Encode JSON to the request body.
            try req.content.encode(["name": name])
        }.map { response in
            print(response)
            return response
        }
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
