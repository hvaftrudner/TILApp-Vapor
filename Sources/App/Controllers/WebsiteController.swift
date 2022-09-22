//
//  File.swift
//  
//
//  Created by Kristoffer Eriksson on 2021-11-29.
//
import Foundation
import Vapor
import Leaf
import Dispatch
import NIOPosix
import Fluent
import SendGrid
import Network



struct WebsiteController: RouteCollection {
    
    let imageFolder = "ProfilePictures/"
    
  func boot(routes: RoutesBuilder) throws {
      //Unprotected
//    routes.get(use: indexHandler)
//    routes.get("acronyms", ":acronymID", use: acronymHandler)
//    routes.get("users", ":userID", use: userHandler)
//    routes.get("users", use: allUsersHandler)
//    routes.get("categories", use: allCategoriesHandler)
//    routes.get("categories", ":categoryID", use: categoryHandler)
//    routes.get("acronyms", "create", use: createAcronymHandler)
//    routes.post("acronyms", "create", use: createAcronymPostHandler)
//    routes.get("acronyms", ":acronymID", "edit", use: editAcronymHandler)
//    routes.post("acronyms", ":acronymID", "edit", use: editAcronymPostHandler)
//    routes.post("acronyms", ":acronymID", "delete", use: deleteAcronymHandler)
//
//    //login
//    routes.get("login", use: loginHandler)
//    let credentialsAuthRoutes = routes.grouped(User.credentialsAuthenticator())
//
//    credentialsAuthRoutes.post("login", use: loginPostHandler)
      
      //Protected with redirect
      let authSessionsRoutes = routes.grouped(User.sessionAuthenticator())
      
      //Login
      authSessionsRoutes.get("login", use: loginHandler)
      let credentialsAuthRoutes = authSessionsRoutes.grouped(User.credentialsAuthenticator())
      credentialsAuthRoutes.post("login", use: loginPostHandler)
      
      authSessionsRoutes.post("logout", use: logoutHandler)
      
      authSessionsRoutes.get("register", use: registerHandler)
      authSessionsRoutes.post("register", use: registerPostHandler)
      
      //PASS
      authSessionsRoutes.get(
       "forgottenPassword",
       use: forgottenPasswordHandler)
      //authSessionsRoutes.get("forgottenPassword", use: forgottenPasswordHandler)
      authSessionsRoutes.post(
       "forgottenPassword",
       use: forgottenPasswordPostHandler)
      //authSessionsRoutes.post("forgottenPassword", use: forgottenPasswordPostHandler)
      //authSessionsRoutes.get("resetPassword", use: resetPasswordHandler)
      authSessionsRoutes.get(
       "resetPassword",
       use: resetPasswordHandler)
      //authSessionsRoutes.post("resetPassword", use: resetPasswordPostHandler)
      authSessionsRoutes.post(
       "resetPassword",
       use: resetPasswordPostHandler)
      
      authSessionsRoutes.get(use: indexHandler)
      authSessionsRoutes.get("acronyms", ":acronymID", use: acronymHandler)
      authSessionsRoutes.get("users", ":userID", use: userHandler)
      authSessionsRoutes.get("users", use: allUsersHandler)
      authSessionsRoutes.get("categories", use: allCategoriesHandler)
      authSessionsRoutes.get("categories", ":categoryID", use: categoryHandler)
      
      //profile
      authSessionsRoutes.get("users", "userID", "profilePicture", use: getUsersProfilePictureHandler)
      
      let protectedRoutes = authSessionsRoutes.grouped(User.redirectMiddleware(path: "/login"))
      
      //Post, Put, Delete
      protectedRoutes.get("acronyms", "create", use: createAcronymHandler)
      protectedRoutes.post("acronyms", "create", use: createAcronymPostHandler)
      protectedRoutes.get("acronyms", ":acronymID", "edit", use: editAcronymHandler)
      protectedRoutes.post("acronyms", ":acronymID", "edit", use: editAcronymPostHandler)
      protectedRoutes.post("acronyms", ":acronymID", "delete", use: deleteAcronymHandler)
      
      //Profile
      protectedRoutes.get("users", ":userID", "addProfilePicture", use: addProfilePictureHandler)
      protectedRoutes.on(.POST, "users", ":userID", "addProfilePicture", body: .collect(maxSize: "1gb"), use: addProfilePicturePostHandler)
  }

  func indexHandler(_ req: Request) -> EventLoopFuture<View> {
    Acronym.query(on: req.db).all().flatMap { acronyms in
      
        let userLoggedIn = req.auth.has(User.self)
        
        let showCookieMessage = req.cookies["cookies-accepted"] == nil
        let context = IndexContext(title: "Home page", acronyms: acronyms, userLoggedIn: userLoggedIn, showCookieMessage: showCookieMessage)
      return req.view.render("index", context)
    }
  }

  func acronymHandler(_ req: Request) -> EventLoopFuture<View> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { acronym in
      let userFuture = acronym.$user.get(on: req.db)
      let categoriesFuture = acronym.$categories.query(on: req.db).all()
      return userFuture.and(categoriesFuture).flatMap { user, categories in
        let context = AcronymContext(
          title: acronym.short,
          acronym: acronym,
          user: user,
          categories: categories)
        return req.view.render("acronym", context)
      }
    }
  }

  func userHandler(_ req: Request) -> EventLoopFuture<View> {
    User.find(req.parameters.get("userID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
      user.$acronyms.get(on: req.db).flatMap { acronyms in
        //let context = UserContext(title: user.name, user: user, acronyms: acronyms)
          let loggedInUser = req.auth.get(User.self)
          //let context = UserContext(title: user.name, user: user, acronyms: acronyms, authenticatedUser: loggedInUser)
          let context = UserContext(
            title: user.name,
            user: user,
            acronyms: acronyms,
            authenticatedUser: loggedInUser)
        return req.view.render("user", context)
      }
    }
  }

  func allUsersHandler(_ req: Request) -> EventLoopFuture<View> {
    User.query(on: req.db).all().flatMap { users in
      let context = AllUsersContext(
        title: "All Users",
        users: users)
      return req.view.render("allUsers", context)
    }
  }

  func allCategoriesHandler(_ req: Request) -> EventLoopFuture<View> {
    Category.query(on: req.db).all().flatMap { categories in
      let context = AllCategoriesContext(categories: categories)
      return req.view.render("allCategories", context)
    }
  }

  func categoryHandler(_ req: Request) -> EventLoopFuture<View> {
    Category.find(req.parameters.get("categoryID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { category in
      category.$acronyms.get(on: req.db).flatMap { acronyms in
        let context = CategoryContext(title: category.name, category: category, acronyms: acronyms)
        return req.view.render("category", context)
      }
    }
  }

  func createAcronymHandler(_ req: Request) -> EventLoopFuture<View> {
//    User.query(on: req.db).all().flatMap { users in
//      let context = CreateAcronymContext(users: users)
//      return req.view.render("createAcronym", context)
//    }
      //let context = CreateAcronymContext()
      let token = [UInt8].random(count: 16).base64
      let context = CreateAcronymContext(csrfToken: token)
      
      req.session.data["CSRF_TOKEN"] = token
      
      return req.view.render("createAcronym", context)
  }

  func createAcronymPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    let data = try req.content.decode(CreateAcronymFormData.self)
    //let acronym = Acronym(short: data.short, long: data.long, userID: data.userID)
      let user = try req.auth.require(User.self)
      
      let expectedToken = req.session.data["CSRF_TOKEN"]
      req.session.data["CSRF_TOKEN"] = nil
      
      guard let csrfToken = data.csrfToken,
            expectedToken == csrfToken
            else {
                throw Abort(.badRequest)
            }
      
      let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
      
    return acronym.save(on: req.db).flatMap {
      guard let id = acronym.id else {
        return req.eventLoop.future(error: Abort(.internalServerError))
      }
      var categorySaves: [EventLoopFuture<Void>] = []
      for category in data.categories ?? [] {
        categorySaves.append(Category.addCategory(category, to: acronym, on: req))
      }
      let redirect = req.redirect(to: "/acronyms/\(id)")
      return categorySaves.flatten(on: req.eventLoop).transform(to: redirect)
    }
  }

    func editAcronymHandler(_ req: Request)
      -> EventLoopFuture<View> {
      return Acronym
        .find(req.parameters.get("acronymID"), on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap { acronym in
          acronym.$categories.get(on: req.db)
            .flatMap { categories in
              let context = EditAcronymContext(
                acronym: acronym,
                categories: categories)
              return req.view.render("createAcronym", context)
            }
        }
    }

  func editAcronymPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
      
      let user = try req.auth.require(User.self)
      let userID = try user.requireID()
      
    let updateData = try req.content.decode(CreateAcronymFormData.self)
    return Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { acronym in
      acronym.short = updateData.short
      acronym.long = updateData.long
        
      acronym.$user.id = userID
        
      guard let id = acronym.id else {
        return req.eventLoop.future(error: Abort(.internalServerError))
      }
      return acronym.save(on: req.db).flatMap {
        acronym.$categories.get(on: req.db)
      }.flatMap { existingCategories in
        let existingStringArray = existingCategories.map {
          $0.name
        }

        let existingSet = Set<String>(existingStringArray)
        let newSet = Set<String>(updateData.categories ?? [])

        let categoriesToAdd = newSet.subtracting(existingSet)
        let categoriesToRemove = existingSet.subtracting(newSet)

        var categoryResults: [EventLoopFuture<Void>] = []
        for newCategory in categoriesToAdd {
          categoryResults.append(Category.addCategory(newCategory, to: acronym, on: req))
        }

        for categoryNameToRemove in categoriesToRemove {
          let categoryToRemove = existingCategories.first {
            $0.name == categoryNameToRemove
          }
          if let category = categoryToRemove {
            categoryResults.append(
              acronym.$categories.detach(category, on: req.db))
          }
        }

        let redirect = req.redirect(to: "/acronyms/\(id)")
        return categoryResults.flatten(on: req.eventLoop).transform(to: redirect)
      }
    }
  }

  func deleteAcronymHandler(_ req: Request) -> EventLoopFuture<Response> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { acronym in
      acronym.delete(on: req.db).transform(to: req.redirect(to: "/"))
    }
  }
    
    func loginHandler(_ req: Request) -> EventLoopFuture<View> {
        let context: LoginContext
        
        if let error = req.query[Bool.self, at: "error"], error {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        
        return req.view.render("login", context)
    }
    
    func loginPostHandler(_ req: Request) -> EventLoopFuture<Response> {
        if req.auth.has(User.self) {
            return req.eventLoop.future(req.redirect(to: "/"))
        } else {
            let context = LoginContext(loginError: true)
            
            return req.view
                .render("login", context)
                .encodeResponse(for: req)
        }
    }
    
    func logoutHandler(_ req: Request) -> Response {
        req.auth.logout(User.self)
        return req.redirect(to: "/")
    }
    
    func registerHandler(_ req: Request) -> EventLoopFuture<View> {
        //let context = RegisterContext()
        
        let context: RegisterContext
        if let message = req.query[String.self, at: "message"] {
            context = RegisterContext(message: message)
        } else {
            context = RegisterContext()
        }
        
        return req.view.render("register", context)
    }
    
    func registerPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        
        do {
            try RegisterData.validate(content: req)
        } catch let error as ValidationsError {
            let message =
                error.description
                    .addingPercentEncoding(
                        withAllowedCharacters: .urlQueryAllowed
                    ) ?? "Unknown error"
            let redirect =
                req.redirect(to: "/register?message=\(message)")
            return req.eventLoop.future(redirect)
        }
        
        let data = try req.content.decode(RegisterData.self)
        let password = try Bcrypt.hash(data.password)
        
        let user = User(
          name: data.name,
          username: data.username,
          password: password,
          email: data.emailAddress)
        
        return user.save(on: req.db).map {
            req.auth.login(user)
            
            return req.redirect(to: "/")
        }
    }
    
    //MARK: Password
//    func forgottenPasswordHandler(_ req: Request) -> EventLoopFuture<View> {
//        req.view.render("forgottenPassword", ["title": "Reset Your Password"])
//    }
    
    func forgottenPasswordHandler(_ req: Request)
      -> EventLoopFuture<View> {
      // 2
      req.view.render(
        "forgottenPassword",
        ["title": "Reset Your Password"])
    }
    
//    func forgottenPasswordPostHandler(_ req: Request) throws -> EventLoopFuture<View> {
//
//        let email = try req.query.get(String.self, at: "email")
//
//        return User.query(on: req.db)
//            .filter(\.$email == email)
//            .first()
//            .flatMap { user in
//                //req.view.render("forgottenPasswordConfirmed")
//
//                guard let user = user else {
//                    req.view.render("forgottenPasswordConfirmed", ["title": "Password reset email sent"])
//                }
//
//                let resetTokenString = Data([UTF8].random(count: 32)).base32EncodedString()
//                let resetToken: ResetPasswordToken
//
//                do {
//                    resetToken = try ResetPasswordToken(token: resetTokenString, userID: user.requireID())
//                } catch {
//                    return req.eventLoop.future(error: error)
//                }
//
//                return resetToken.save(on: req.db).flatMap {
//                    let emailContent = """
//                      <p>You've requested to reset your password. <a
//                      href="http://localhost:8080/resetPassword?\
//                      token=\(resetTokenString)">
//                      Click here</a> to reset your password.</p>
//                      """
//                    let emailAddress = EmailAddress(email: user.email, name: user.name)
//                    let fromEmail = EmailAddress(email: "<krill_eriksson@hotmail.com>", name: "TIL Vapor")
//                    let emailConfig = Personalization(to: [emailAddress], subject: "Reset your password")
//
//                    let email = SendGridEmail(personalizations: [emailConfig], from: fromEmail, content: [["type": "text/html", "value": emailContent ]])
//
//                    let emailSend: EventLoopFuture<Void>
//
//                    do {
//                        emailSend = try req.application
//                            .sendgrid
//                            .client
//                            .send(email: email, on: req.eventLoop)
//                    } catch {
//                        return req.eventLoop.future(error: error)
//                    }
//
//                    return emailSend.flatMap {
//                        return req.view.render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
//                    }
//                }
//            }
//    }
    
    func forgottenPasswordPostHandler(_ req: Request) throws -> EventLoopFuture<View> {
    // 2
        let email = try req.content.get(String.self, at: "email")
    // 3
        return User.query(on: req.db)
          .filter(\.$email == email)
          .first()
          .flatMap { user in
    // 4
              guard let user = user else {
                  return req.view.render(
                      "forgottenPasswordConfirmed",
                      ["title": "Password Reset Email Sent"])
                  }
                  // 2
              let resetTokenString = Data([UInt8].random(count: 32)).base32EncodedString()
                  // 3
              let resetToken: ResetPasswordToken
              do {
                resetToken = try ResetPasswordToken(
                    token: resetTokenString,
                    userID: user.requireID())
                } catch {
                    return req.eventLoop.future(error: error)
                }
                  // 4
              return resetToken.save(on: req.db).flatMap {
                    // 5
                    let emailContent = """
                    <p>You've requested to reset your password. <a
                    href="http://localhost:8080/resetPassword?\
                    token=\(resetTokenString)">
                    Click here</a> to reset your password.</p>
                    """
                    // 6
                    let emailAddress = EmailAddress(email: user.email, name: user.name)
                    let fromEmail = EmailAddress(email: "krill_eriksson@hotmail.com", name: "TIL Vapor")
                    // 7
                    let emailConfig = Personalization(to: [emailAddress], subject: "Reset Your Password")
                  // 8
                    let email = SendGridEmail(personalizations: [emailConfig], from: fromEmail,
                      content: [
                        ["type": "text/html",
                        "value": emailContent]
                      ])
                  // 9
                    let emailSend: EventLoopFuture<Void>
                    do {
                      emailSend =
                        try req.application
                          .sendgrid
                          .client
                          .send(email: email, on: req.eventLoop)
                  } catch {
                      return req.eventLoop.future(error: error)
                     }
                     return emailSend.flatMap {
                       // 10
                       return req.view.render(
                         "forgottenPasswordConfirmed",
                         ["title": "Password Reset Email Sent"]
                       )
                   }
              }
          }
    }
    
    func resetPasswordHandler(_ req: Request) -> EventLoopFuture<View> {
    // 1
        guard let token = try? req.query.get(String.self, at: "token") else {
            return req.view.render("resetPassword", ResetPasswordContext(error: true))
        }
    // 2
        return ResetPasswordToken.query(on: req.db)
          .filter(\.$token == token)
          .first()
          // 3
          .unwrap(or: Abort.redirect(to: "/"))
          .flatMap { token in
    // 4
            token.$user.get(on: req.db).flatMap { user in
              do {
                try req.session.set("ResetPasswordUser", to: user)
              } catch {
                return req.eventLoop.future(error: error)
              }
    // 5
              return token.delete(on: req.db)
            }
    }       .flatMap {
    // 6
            req.view.render(
              "resetPassword",
              ResetPasswordContext()
            )
        }
    }

// 3
    func resetPasswordPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    // 1
        let data = try req.content.decode(ResetPasswordData.self)
        // 2
        let resetPasswordUser = try req.session.get("ResetPasswordUser", as: User.self)
        req.session.data["ResetPasswordUser"] = nil
    // 4
        let newPassword = try Bcrypt.hash(data.password)
    // 5
        return try User.query(on: req.db)
          .filter(\.$id == resetPasswordUser.requireID())
          .set(\.$password, to: newPassword)
          .update()
          .transform(to: req.redirect(to: "/login"))
    }
    
    func addProfilePictureHandler(_ req: Request) -> EventLoopFuture<View> {
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                req.view.render("addProfilePicture",
                                ["title" : "Add Profile Picture" ,
                                 "username" : user.name
                                ]
                )
            }
    }
    
    func addProfilePicturePostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        
        let data = try req.content.decode(ImageUploadData.self)
        
        return User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                let userID: UUID
                
                do {
                    userID = try user.requireID()
                } catch {
                    return req.eventLoop.future(error: error)
                }
                
                let name = "\(userID)-\(UUID()).jpg"
                let path = req.application.directory.workingDirectory + imageFolder + name
                
                return req.fileio
                    .writeFile(.init(data: data.picture), at: path)
                    .flatMap {
                        user.profilePicture = name
                        let redirect = req.redirect(to: "/users/\(userID)")
                        return user.save(on: req.db).transform(to: redirect)
                    }
            }
    }
    
    func getUsersProfilePictureHandler(_ req: Request) -> EventLoopFuture<Response> {
        
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { user in
                
                guard let filename = user.profilePicture else {
                    throw Abort(.notFound)
                }
                
                let path = req.application.directory.workingDirectory + imageFolder + filename
                
                return req.fileio.streamFile(at: path)
            }
    }
 }

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]
    let userLoggedIn: Bool
    let showCookieMessage: Bool
}

struct AcronymContext: Encodable {
  let title: String
  let acronym: Acronym
  let user: User
  let categories: [Category]
}

struct UserContext: Encodable {
  let title: String
  let user: User
  let acronyms: [Acronym]
    
    let authenticatedUser: User?
    
}

struct AllUsersContext: Encodable {
  let title: String
  let users: [User]
}

struct AllCategoriesContext: Encodable {
    let title = "All Categories"
    let categories: [Category]
}

struct CategoryContext: Encodable {
  let title: String
  let category: Category
  let acronyms: [Acronym]
}

struct CreateAcronymContext: Encodable {
  let title = "Create An Acronym"
  //let users: [User]
    let csrfToken: String
}

struct EditAcronymContext: Encodable {
  let title = "Edit Acronym"
  let acronym: Acronym
  //let users: [User]
  let editing = true
  let categories: [Category]
}

struct CreateAcronymFormData: Content {
  //let userID: UUID
  let short: String
  let long: String
  let categories: [String]?
    
    let csrfToken: String?
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    
    init(loginError: Bool = false){
        self.loginError = loginError
    }
}

struct RegisterContext: Encodable {
    let title = "Register"
    
    let message: String?
    
    init(message: String? = nil){
        self.message = message
    }
}

struct RegisterData: Content {
    let name: String
    let username: String
    let password: String
    let confirmPassword: String
    
    let emailAddress: String
}

struct ResetPasswordContext: Encodable {
  let title = "Reset Password"
  let error: Bool?
  init(error: Bool? = false) {
    self.error = error
  }
}

struct ResetPasswordData: Content {
  let password: String
  let confirmPassword: String
}

struct ImageUploadData: Content {
    var picture: Data
}

extension RegisterData: Validatable {
    public static func validations(_ validations: inout Validations) {
        
        validations.add("name", as: String.self, is: .ascii)
        
        validations.add("username", as: String.self, is: .alphanumeric && .count(3...))
        
        validations.add("password", as: String.self, is: .count(8...))
        
        validations.add("zipCode", as: String.self, is: .zipCode, required: false)
        
        validations.add("emailAddress", as: String.self, is: .email)
    }
}

extension ValidatorResults {

    struct ZipCode {
        let isValidZipCode: Bool
    }
}

extension ValidatorResults.ZipCode: ValidatorResult {

    var isFailure: Bool {
        !isValidZipCode
    }

    var successDescription: String? {
        "is a valid zip code"
    }

    var failureDescription: String? {
        "is not a valid zip code"
    }
}


extension Validator where T == String {
    
    private static var zipCodeRegex: String {
        "^\\d{5}(?:[-\\s]\\d{4})?$"
    }
    
    public static var zipCode: Validator<T> {
        
        Validator { input -> ValidatorResult in
            guard let
                    range = input.range(of: zipCodeRegex, options: [.regularExpression]),
                  range.lowerBound == input.startIndex && range.upperBound == input.endIndex
            else {
                return ValidatorResults.ZipCode(isValidZipCode: false)
            }
                    
            return ValidatorResults.ZipCode(isValidZipCode: true)
        }
    }
}
