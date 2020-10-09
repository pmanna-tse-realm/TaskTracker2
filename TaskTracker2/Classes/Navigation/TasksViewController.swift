//
//  TasksViewController.swift
//  TaskTracker2
//
//  Created by Paolo Manna on 14/08/2020.
//  Copyright © 2020 MongoDB. All rights reserved.
//

import Realm
import RealmSwift
import UIKit

class TasksViewController: UITableViewController, Storyboarded {
	weak var coordinator: MainCoordinator?
	
	var project: Project?
	var realm: Realm!
	var partitionValue: ObjectId!
	var tasks: Results<Task>!
	var notificationToken: NotificationToken?
	
	@IBOutlet var addButton: UIBarButtonItem!

	override func viewDidLoad() {
		super.viewDidLoad()

		addButton							= UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonDidClick))
		navigationItem.rightBarButtonItem	= addButton
		
		tableView.tableFooterView	= UIView(frame: .zero)
		
		title	= project?.name
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		notificationToken?.invalidate()
		notificationToken	= nil
		realm				= nil
		project				= nil
		
		super.viewDidDisappear(animated)
	}
	
	// MARK: - Actions
    
	func loadFromDB() {
		let nav	= navigationController as? NavigationControllerWithError
		
		guard project != nil, realm != nil, let syncConfiguration = realm.configuration.syncConfiguration,
			let syncPartitionValue = syncConfiguration.partitionValue
		else {
			nav?.postErrorMessage(message: "Sync configuration not found! Realm not opened with sync?", isError: true)
			
			return
		}
		
		// Partition value must be of ObjectId type.
		partitionValue = syncPartitionValue.objectIdValue
		
		tasks = realm.objects(Task.self).sorted(byKeyPath: "_id")
		
		guard tasks != nil else {
			nav?.postErrorMessage(message: "No projects found", isError: true)
			
			return
		}
		
		// Observe the projects for changes.
		notificationToken = tasks.observe { [weak self] changes in
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
    
	@IBAction func addButtonDidClick() {
		guard realm != nil else { return }
		
		// User clicked the add button.
        
		let alertController = UIAlertController(title: "Add Task", message: "", preferredStyle: .alert)

		alertController.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ -> Void in
			guard let self = self else { return }
			
			let textField = alertController.textFields![0] as UITextField
			let project = Task(partition: self.partitionValue, name: textField.text ?? "New Task")
                
			// All writes must happen in a write block.
			try! self.realm.write {
				self.realm.add(project)
			}
		}))
		alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		alertController.addTextField(configurationHandler: { (textField: UITextField!) -> Void in
			textField.placeholder = "New Task Name"
		})
		present(alertController, animated: true, completion: nil)
	}

	// MARK: - Table View

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return tasks?.count ?? 0
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell	= tableView.dequeueReusableCell(withIdentifier: "taskCell", for: indexPath)
		let task	= tasks[indexPath.row]
	
		cell.textLabel!.text = task.name
		switch task.statusEnum {
		case .Open:
			cell.detailTextLabel?.text	= nil
			cell.accessoryType			= .none
		case .InProgress:
			cell.detailTextLabel?.text	= "In Progress"
			cell.accessoryType			= .none
		case .Complete:
			cell.detailTextLabel?.text	= nil
			cell.accessoryType			= .checkmark
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete else { return }
		
		let task = tasks[indexPath.row]
		
		try! realm.write {
			// Delete the task.
			realm.delete(task)
		}
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		// User selected a task in the table. We will present a list of actions that the user can perform on this task.
		let task = tasks[indexPath.row]

		// Create the AlertController and add its actions.
		let actionSheet = UIAlertController(title: task.name, message: "Select an action", preferredStyle: .actionSheet)

		actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

		// If the task is not in the Open state, we can set it to open. Otherwise, that action will not be available.
		// We do this for the other two states -- InProgress and Complete.
		if task.statusEnum != .Open {
			actionSheet.addAction(UIAlertAction(title: "Open", style: .default) { [weak self] _ in
				// Any modifications to managed objects must occur in a write block.
				// When we modify the Task's state, that change is automatically reflected in the realm.
				try? self?.realm.write {
					task.statusEnum = .Open
				}
			})
		}

		if task.statusEnum != .InProgress {
			actionSheet.addAction(UIAlertAction(title: "Start Progress", style: .default) { [weak self] _ in
				try? self?.realm.write {
					task.statusEnum = .InProgress
				}
			})
		}

		if task.statusEnum != .Complete {
			actionSheet.addAction(UIAlertAction(title: "Complete", style: .default) { [weak self] _ in
				try? self?.realm.write {
					task.statusEnum = .Complete
				}
			})
		}

		// Show the actions list.
		present(actionSheet, animated: true, completion: nil)
	}
}
