//
//  MainCoordinator.swift
//  TaskTracker2
//
//  Created by Paolo Manna on 14/08/2020.
//  Copyright © 2020 MongoDB. All rights reserved.
//

import RealmSwift
import UIKit

class MainCoordinator: NSObject, Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: NavigationControllerWithError

	init(navigationController: NavigationControllerWithError) {
		self.navigationController = navigationController
	}

	func start() {
		app.syncManager.logLevel					= .info
		app.configuration.defaultRequestTimeoutMS	= 15000
		
		let vc = ProjectsViewController.instantiate()
        
		vc.coordinator	= self
		
		navigationController.pushViewController(vc, animated: false)
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
			self?.showLoginWindow()
		}
	}
	
	@IBAction func loginCompleted() {
		if let vc = navigationController.topViewController as? ProjectsViewController {
			vc.loadFromDB()
		}
	}
	
	@IBAction func showLoginWindow() {
		let vc = LoginViewController.instantiate()
        
		vc.coordinator	= self
		
		navigationController.present(vc, animated: true) {
			// Something
		}
	}
	
	@IBAction func signOut() {
		let vc = LoginViewController.instantiate()
        
		vc.coordinator	= self
		vc.signOut()
		
		navigationController.present(vc, animated: true) {
			// Something
		}
	}
	
	func showTasks(for project: Project, in realm: Realm) {
#if DEBUG
		// mongodb-atlas is the name of cluster service
		if let user = app.currentUser, let identity = try? ObjectId(string: user.id) {
			let client = user.mongoClient("mongodb-atlas")
			
			// Select the database
			let database = client.database(named: "tracker")

			// Select the collection
			let collection = database.collection(withName: "projects")

			// Run the query

			collection.find(filter: ["_partition": AnyBSON(identity)]) { result in
				// Note: this completion handler may be called on a background thread.
				//       If you intend to operate on the UI, dispatch back to the main
				//       thread with `DispatchQueue.main.sync {}`.

				switch result {
				case let .success(results):
					// Print each document.
					print("Results:")
					results.forEach { document in
						print("Document:")
						document.forEach { key, value in
							print("\tkey: \(key), value: \(value ?? "<NULL>")")
						}
					}
				case let .failure(error):
					// Handle errors
					print("Call to MongoDB failed: \(error.localizedDescription)")
				}
			}
		}
#endif
		let vc = TasksViewController.instantiate()
        
		vc.coordinator	= self
		vc.project		= project
		vc.realm		= realm
		
		vc.loadFromDB()
		
		navigationController.pushViewController(vc, animated: true)
	}
}
