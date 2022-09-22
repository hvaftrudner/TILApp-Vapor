//
//  File.swift
//  
//
//  Created by Kristoffer Eriksson on 2021-10-14.
//

import Foundation
import Fluent

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .id()
            .field("name", .string, .required)
            .field("username", .string, .required)
            .field("password", .string, .required)
            .field("siwaIdentifier", .string)
            .unique(on: "username")
            .field("email", .string, .required)
            .unique(on: "email")
            .field("profilePicture", .string)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users").delete()
    }
}
