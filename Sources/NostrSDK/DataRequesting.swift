//
//  DataRequesting.swift
//  
//
//  Created by Bryan Montz on 6/14/23.
//

import Foundation

/// An interface for retrieving data for a URL.
///
/// Use this protocol to create a mock for URLSession and return custom data.
@available(iOS 15.0.0, *)
public protocol DataRequesting {
    @available(iOS 15.0.0, *)
    func data(from url: URL, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse)
}

@available(iOS 15.0.0, *)
extension URLSession: DataRequesting {}


@available(iOS 12.0.0, *)
/// A non-async interface for retrieving data for a URL using a completion handler.
public protocol NonAsyncDataRequesting {
    func data(from url: URL, completionHandler: @escaping (Result<(Data, URLResponse), Error>) -> Void)
}

@available(iOS 12.0.0, *)
extension URLSession: NonAsyncDataRequesting {
    public func data(from url: URL, completionHandler: @escaping (Result<(Data, URLResponse), Error>) -> Void) {
        
        // Create a URLSessionDataTask
        let task = self.dataTask(with: url) { (data, response, error) in
            // Check for a network error first
            if let error = error {
                completionHandler(.failure(error))
                return
            }

            // Check if data and a response were received
            guard let data = data, let response = response else {
                let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data or response received."])
                completionHandler(.failure(error))
                return
            }
            
            // If successful, pass the data and response to the completion handler
            completionHandler(.success((data, response)))
        }

        // Start the task
        task.resume()
    }
}
