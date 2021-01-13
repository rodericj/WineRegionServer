import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    try app.register(collection: RegionController())
//    router.get("regions", use: regionController.index)
//    router.post("region", use: regionController.create)
//    router.delete("region", Region.parameter, use: regionController.delete)
}
