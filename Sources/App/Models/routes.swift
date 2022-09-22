import Fluent
import Vapor

func routes(_ app: Application) throws {
    
//    app.get { req in
//        return "It works!"
//    }
      
    app.get("hello") { req -> String in
        return "Hello, world!"
    }
    
    //Acronym controller
    let acronymsController = AcronymsController()
    try app.register(collection: acronymsController)
    
    let usersController = UsersController()
    try app.register(collection: usersController)
    
    let categoriesController = CategoriesController()
    try app.register(collection: categoriesController)
    
    let websiteController = WebsiteController()
    try app.register(collection: websiteController)
    
    let imperialController = ImperialController()
    try app.register(collection: imperialController)
}
