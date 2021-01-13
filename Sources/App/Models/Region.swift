import Fluent
import Vapor

final class Region: Model, Content {
    static let schema = "region"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "url")
    var url: String

    //    @Parent


    init() { }

    init(id: UUID? = nil, title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }
}
