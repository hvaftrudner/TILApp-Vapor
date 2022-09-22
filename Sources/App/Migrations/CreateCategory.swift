//
//  File.swift
//  
//
//  Created by Kristoffer Eriksson on 2021-11-16.
//

import Foundation
import Fluent

struct CreateCategory: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("categories")
            .id()
            .field("name", .string, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("categories")
            .delete()
    }
}
