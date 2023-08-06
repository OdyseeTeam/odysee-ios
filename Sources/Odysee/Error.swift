//
//  Error.swift
//  
//
//  Created by Alsey Coleman Miller on 8/5/23.
//

import Foundation

/// Odysee REST API Error
public enum OdyseeError: Error {
    
    case invalidStatusCode(Int)
    case invalidResponse(Data)
}
