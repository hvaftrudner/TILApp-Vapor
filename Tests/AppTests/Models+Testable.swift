//
//  File.swift
//  
//
//  Created by Kristoffer Eriksson on 2021-11-17.
//
import Foundation
@testable import App
import Fluent
import Vapor

extension User {
    static func create(name: String = "Luke", username: String? = nil, on database: Database) throws -> User {
        
        let createUsername: String
        
        if let suppliesUsername = username {
            createUsername = suppliesUsername
        } else {
            createUsername = UUID().uuidString
        }
        
        let password = try Bcrypt.hash("password")
        let user = User(
          name: name,
          username: createUsername,
          password: password,
          email: "\(createUsername)@test.com")
        
        try user.save(on: database).wait()
        return user
    }
}

extension Acronym {
    static func create(short: String = "TIL", long: String = "Today I Learned", user: User? = nil, on database: Database) throws -> Acronym {
        var acronymsUser = user
        
        if acronymsUser == nil {
            acronymsUser = try User.create(on: database)
        }
        
        let acronym = Acronym(short: short, long: long, userID: acronymsUser!.id!)
        try acronym.save(on: database).wait()
        return acronym
    }
}

extension App.Category {
    static func create(name: String = "Random", on database: Database) throws -> App.Category {
        let category = Category(name: name)
        
        try category.save(on: database).wait()
        print("%%%%%%%%%%%%%%%%%%%\(category)")
        return category
    }
}


