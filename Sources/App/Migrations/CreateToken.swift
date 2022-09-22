//
//  File.swift
//  
//
//  Created by Kristoffer Eriksson on 2021-12-19.
//

import Fluent

struct CreateToken: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tokens")
            .id()
            .field("value", .string, .required)
            .field("userID", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tokens").delete()
    }
}
