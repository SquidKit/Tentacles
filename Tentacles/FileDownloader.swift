//
//  FileDownloader.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/26/24.
//  Copyright © 2024 Squid Store. All rights reserved.
//

import Foundation

/// The `FileDownloader` class provides simple semantics for downloading a file resource as Data
open class FileDownloader {
    public static var shared = FileDownloader()
    
    /**
    `get` will perform the image download request.
        
    - Parameter url:        The fully qualified URL of the requested file resource.
    - Parameter completion: The completion handler which is called once the request is completed.
    */
    open func get(url: URL, completion: @escaping EndpointCompletion) {
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            let result = Result(data: data, urlResponse: response ?? URLResponse(), error: error, responseType: .data, requestType: nil, requestData: nil)
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        task.resume()
    }
    
    /**
    `cancel` will cancel the file download request for the given URL.
        
    - Parameter url:        The fully qualified URL of the request to be canceled.
    */
    open func cancel(url: URL) {
        let urlString = url.absoluteString
        
        URLSession.shared.getTasksWithCompletionHandler { (dataTasks, _, _) in
            for task in dataTasks {
                if let candidateURL = task.originalRequest?.url, candidateURL.absoluteString == urlString {
                    task.cancel()
                    break
                }
            }
        }
    }
}
