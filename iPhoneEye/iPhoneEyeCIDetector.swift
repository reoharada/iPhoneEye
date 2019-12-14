//
//  iPhoneEyeCIDetector.swift
//  iPhoneEye
//
//  Created by REO HARADA on 2019/12/14.
//  Copyright © 2019 reo harada. All rights reserved.
//

import UIKit

class iPhoneEyeCIDetector {
    static let shareInstance = iPhoneEyeCIDetector()
    let detector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyHigh] )!
    
    func findHuman(_ image: CIImage) -> Int {
        let faces = detector.features(in: image)
        faces.forEach { (feat) in
            print(feat.bounds)
        }
        return faces.count
    }
    
}
