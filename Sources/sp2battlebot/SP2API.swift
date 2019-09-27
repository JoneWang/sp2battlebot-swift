//
//  SP2API.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SP2API {
    static let baseURL = URL(string: "https://app.splatoon2.nintendo.net")!

    static func getRequest<T: Decodable>(_ type: T.Type,
                                         iksmSession: String,
                                         path: String,
                                         _ result: @escaping (T?, Int?, Error?) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.httpAdditionalHeaders = [
            "Cookie": "iksm_session=\(iksmSession); path=/; domain=.app.splatoon2.nintendo.net;",
            "Accept": "application/json"
        ]

        // Debug: Use proxy on MacOS
        // let proxy = [kCFNetworkProxiesHTTPEnable: 1,
        //              kCFNetworkProxiesHTTPProxy: "127.0.0.1",
        //              kCFNetworkProxiesHTTPPort: 1387] as [String: Any]
        // sessionConfiguration.connectionProxyDictionary = proxy

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

    static func battleList(context: DataContext,
                           result: @escaping (SP2BattleOverview?, Int) -> Void) {
        if let iksmSession = context.user.iksmSession {
            getRequest(SP2BattleOverview.self,
                       iksmSession: iksmSession,
                       path: "/api/results") {
                obj, statusCode, err in
                if err == nil {
                    result(obj, statusCode!)
                } else {
                    print(err.debugDescription)
                }
            }
        } else {
            result(nil, 403)
        }
    }

    static func battle(context: DataContext,
                       id: String,
                       result: @escaping (SP2Battle?, Int) -> Void) {
        if let iksmSession = context.user.iksmSession {
            getRequest(SP2Battle.self,
                       iksmSession: iksmSession,
                       path: "/api/results/\(id)") {
                obj, statusCode, err in
                if let obj = obj, err == nil {
                    result(obj, statusCode!)
                } else {
                    print(err.debugDescription)
                }
            }
        } else {
            result(nil, 403)
        }
    }
}
