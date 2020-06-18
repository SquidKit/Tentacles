//
//  ImageDownloader.swift
//  Tentacles
//
//  Created by Mike Leavy on 6/18/20.
//  Copyright © 2020 Squid Store. All rights reserved.
//

import UIKit

/// The `ImageDownloader` class provides simple semantics for downloading an image resource.
open class ImageDownloader {
    public static var shared = ImageDownloader()
    
    /**
    `get` will perform the image download request.
        
    - Parameter url:        The fully qualified URL of the requested image resource.
    - Parameter completion: The completion handler which is called once the request is completed.
    */
    open func get(url: URL, completion: @escaping EndpointCompletion) {
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            let result = Result(data: data, urlResponse: response ?? URLResponse(), error: error, responseType: .image)
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        task.resume()
    }
}
