//
//  File.swift
//  
//
//  Created by Kristoffer Eriksson on 2022-02-22.
import Fluent
struct CreateResetPasswordToken: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema("resetPasswordTokens")
      .id()
      .field("token", .string, .required)
      .field(
        "userID",
        .uuid,
        .required,
        .references("users", "id"))
      .unique(on: "token")
.create() }
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("resetPasswordTokens").delete()
  }
}
