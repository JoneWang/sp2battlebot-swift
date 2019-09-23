//
//  SP2API.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import Foundation

struct SP2API2 {
    static let baseURL = URL(string: "https://app.splatoon2.nintendo.net")!
    
    static func getRequest<T: Decodable>(_ type: T.Type, path: String, _ result: @escaping (T?, Int?, Error?) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpAdditionalHeaders = [
            "Cookie": "iksm_session=\(BotController.shared.onlineSession); path=/; domain=.app.splatoon2.nintendo.net;",
            "Accept": "application/json"
        ]
        
        let session = URLSession(configuration: sessionConfiguration)

        session.dataTask(with: request) { data, response, err in
            var obj: T?
            if let data = data {
                obj = try? JSONDecoder().decode(T.self, from: data) as T
            }
            
            let httpResponse = response as? HTTPURLResponse
            result(obj, httpResponse?.statusCode, err)
        }.resume()
    }
    
    static func battleList(result: @escaping ([SP2Battle], Int) -> Void) {
        getRequest(SP2BattleList.self, path: "/api/results") {
            obj, statusCode, err in
            if err == nil {
                result(obj?.battles ?? [], statusCode!)
            }
            else {
                print(err.debugDescription)
            }
        }
    }
    
    static func battle(id: String, result: @escaping (SP2Battle, Int) -> Void) {
        getRequest(SP2Battle.self, path: "/api/results/\(id)") {
            obj, statusCode, err in
            if let obj = obj, err == nil {
                result(obj, statusCode!)
            }
            else {
                print(err.debugDescription)
            }
        }
    }
}
