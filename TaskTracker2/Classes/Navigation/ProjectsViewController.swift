//
//  ProjectsViewController.swift
//  TaskTracker2
//
//  Created by Paolo Manna on 14/08/2020.
//  Copyright © 2020 MongoDB. All rights reserved.
//

import Realm
import RealmSwift
import UIKit

class ProjectsViewController: UITableViewController, Storyboarded {
	weak var coordinator: MainCoordinator?
	
	var realm: Realm!
	var projects: Results<Project>!
	var notificationToken: NotificationToken?
	var partitionValue: ObjectId!
	
	@IBOutlet var logInOutButton: UIBarButtonItem!
	@IBOutlet var addButton: UIBarButtonItem!

	override func viewDidLoad() {
		super.viewDidLoad()
		
		logInOutButton						= UIBarButtonItem(title: "Log In", style: .plain, target: self, action: #selector(logOutButtonDidClick))
		navigationItem.leftBarButtonItem	= logInOutButton

		addButton							= UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonDidClick))
		addButton.isEnabled					= false
		navigationItem.rightBarButtonItem	= addButton
		
		tableView.tableFooterView	= UIView(frame: .zero)
	}
	
	// MARK: - Actions
    
	func loadFromDB() {
		let nav	= navigationController as? NavigationControllerWithError
		
		if realm == nil {
			guard let user = app.currentUser else {
				nav?.postErrorMessage(message: "Must be logged in to access this view", isError: true)
				
				return
			}
			let userIdentity = user.id
			
			partitionValue = try? ObjectId(string: userIdentity)
			guard partitionValue != nil else {
				nav?.postErrorMessage(message: "Couldn't get User ID to partition data", isError: true)
			   
				return
			}

			// Open a realm with the partition key set to the user.
			// TODO: When support for user data is available, use the user data's list of
			// available projects.
			do {
				realm = try Realm(configuration: user.configuration(partitionValue: partitionValue))
			} catch {
				nav?.postErrorMessage(message: error.localizedDescription, isError: true)
				
				return
			}
		}
		
		logInOutButton.title	= "Log Out"
		addButton.isEnabled		= true
		
		// Access all objects in the realm, sorted by _id so that the ordering is defined.
		projects = realm.objects(Project.self).sorted(byKeyPath: "_id")

		guard projects != nil else {
			nav?.postErrorMessage(message: "No projects found", isError: true)
			
			return
		}
		
		// Observe the projects for changes.
		notificationToken = projects.observe { [weak self] changes in
			guard let tableView = self?.tableView else { return }
			switch changes {
			case .initial:
				// Results are now populated and can be accessed without blocking the UI
				tableView.reloadData()
			case let .update(_, deletions, insertions, modifications):
				// Query results have changed, so apply them to the UITableView.
				tableView.beginUpdates()
				// It's important to be sure to always update a table in this order:
				// deletions, insertions, then updates. Otherwise, you could be unintentionally
				// updating at the wrong index!
				tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) },
				                     with: .automatic)
				tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) },
				                     with: .automatic)
				tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) },
				                     with: .automatic)
				tableView.endUpdates()
			case let .error(error):
				// An error occurred while opening the Realm file on the background worker thread
				nav?.postErrorMessage(message: error.localizedDescription, isError: true)
			}
		}
	}
	
	@IBAction func logOutButtonDidClick() {
		if realm == nil {
			coordinator?.showLoginWindow()
		} else {
			let alertController = UIAlertController(title: "Log Out", message: "", preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: "Yes, Log Out", style: .destructive, handler: { _ -> Void in
				app.currentUser?.logOut(completion: { [weak self] _ in
					self?.notificationToken?.invalidate()
					self?.notificationToken		= nil
					self?.realm					= nil
					self?.projects				= nil
					
					DispatchQueue.main.sync { [weak self] in
						self?.tableView.reloadData()
						
						self?.logInOutButton.title	= "Log In"
						self?.addButton.isEnabled	= false
						self?.coordinator?.signOut()
					}
				})
			}))
			alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
			present(alertController, animated: true, completion: nil)
		}
	}
    
	@IBAction func addButtonDidClick() {
		guard realm != nil else { return }
		
		// User clicked the add button.
        
		let alertController = UIAlertController(title: "Add Project", message: "", preferredStyle: .alert)

		alertController.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ -> Void in
			guard let self = self else { return }
			
			let textField = alertController.textFields![0] as UITextField
			let project = Project(partition: self.partitionValue, name: textField.text ?? "New Project")
                
			// All writes must happen in a write block.
			try! self.realm.write {
				self.realm.add(project)
			}
		}))
		alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		alertController.addTextField(configurationHandler: { (textField: UITextField!) -> Void in
			textField.placeholder = "New Project Name"
		})
		present(alertController, animated: true, completion: nil)
	}

	// MARK: - Table View

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return projects?.count ?? 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		var cell: UITableViewCell!
		
		if let projects = projects, !projects.isEmpty {
			let project	= projects[indexPath.row]
		
			cell	= tableView.dequeueReusableCell(withIdentifier: "projectCell", for: indexPath)
		
			cell.textLabel!.text = project.name
		} else {
			cell	= tableView.dequeueReusableCell(withIdentifier: "noDataCell", for: indexPath)
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		// Return false if you do not want the specified item to be editable.
		if let projects = projects, !projects.isEmpty {
			return true
		}
		return false
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete else { return }
		
		// The user can swipe to delete Projects.
		let project = projects[indexPath.row]
		
		// Delete all related tasks
		project.deleteRelatedTasks(in: realm)
		
		// All modifications must happen in a write block.
		try! realm.write {
			// Delete the project.
			realm.delete(project)
		}
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		if let user = app.currentUser, let projects = projects, !projects.isEmpty {
			let project		= projects[indexPath.row]
			guard let projectRealm = try? Realm(configuration: user.configuration(partitionValue: project._id)) else {
				(navigationController as? NavigationControllerWithError)?.postErrorMessage(message: "Cannot proceed to read project's tasks")
				
				return
			}
			
			coordinator?.showTasks(for: project, in: projectRealm)
		}
	}
}
