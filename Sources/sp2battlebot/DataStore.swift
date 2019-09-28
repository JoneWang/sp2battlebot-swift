//
// Created by Jone Wang on 25/9/2019.
//

import Foundation
import SQLite

enum DataStoreError: Error {
    case DatabaseConnectionError
    case InsertError
    case DeleteError
    case SearchError
    case NilInData
    case Error
}

class DataStore {
    static var shared = DataStore()

    var db: Connection {
        get {
            // SQLite.swift 问题
            // linux 下必须每次执行都获取连接，否则再次启动连接会数据库损坏
            return getConnection()
        }
    }

    func getConnection() -> Connection {
        do {
            let currentPath = FileManager.default.currentDirectoryPath
            let sqlitePath = "\(currentPath)/bot.sqlite3"
            print("sqlite path: \(sqlitePath)")
            return try Connection(sqlitePath)
        } catch {
            print("SQLite error: \(error)")
            exit(1)
        }
    }

    func createTables() throws {
        do {
            try UserDataHelper.createTable()
        } catch {
            print(error)
            throw DataStoreError.DatabaseConnectionError
        }
    }
}
