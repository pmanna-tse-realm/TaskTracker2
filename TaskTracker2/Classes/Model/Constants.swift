//
//  Constants.swift
//  TaskTracker2
//
//  Created by Paolo Manna on 14/08/2020.
//  Copyright © 2020 MongoDB. All rights reserved.
//

import Foundation
import RealmSwift

struct Constants {
	// Set this to your Realm App ID found in the Realm UI.
	static let REALM_APP_ID = "task-tracker-tutorial-hkcfn"
	static let GOOGLE_CLIENT_ID = "997951006654-olgel1qkb3urvklg4hjqg93ufal4cdu1.apps.googleusercontent.com"
	static let GOOGLE_SERVER_CLIENT_ID = "997951006654-pp1d0jo72dhqlcglu6ruqqtk1padbg6s.apps.googleusercontent.com"
}

let app = App(id: Constants.REALM_APP_ID)
