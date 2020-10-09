//
//  Settings+Application.swift
//  TaskTracker2
//
//  Created by Paolo Manna on 14/08/2020.
//  Copyright © 2020 MongoDB. All rights reserved.
//

import Foundation

extension Settings {
	var userName: String? {
		get { return value(forKey: "UserName") as? String }
		set { setValue(newValue, forKey: "UserName") }
	}
}
