//
//  GoogleLoginViewController.swift
//  TaskTracker2
//
//  Created by Paolo Manna on 05/10/2020.
//  Copyright © 2020 MongoDB. All rights reserved.
//

import GoogleSignIn
import RealmSwift
import UIKit

class GoogleLoginViewController: LoginViewController, GIDSignInDelegate {
	@IBOutlet var googleSignInButton: GIDSignInButton!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		if GIDSignIn.sharedInstance().clientID == nil {
			GIDSignIn.sharedInstance().clientID			= Constants.GOOGLE_CLIENT_ID
			GIDSignIn.sharedInstance().serverClientID	= Constants.GOOGLE_SERVER_CLIENT_ID
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
				
		GIDSignIn.sharedInstance().delegate						= self
		GIDSignIn.sharedInstance()?.presentingViewController	= self

		// Automatically sign in the user.
		// FIXME: Apparently, that doesn't work so well, Atlas server can't connect, avoiding for now
//		GIDSignIn.sharedInstance()?.restorePreviousSignIn()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		googleSignInButton.colorScheme	= .dark
		googleSignInButton.style		= .wide
	}
	
	// MARK: - Actions
	
	@IBAction override func signOut() {
		switch authType {
		case .google:
			GIDSignIn.sharedInstance()?.signOut()
		default:
			break
		}
		
		super.signOut()
	}
	
	// MARK: - GIDSignInDelegate
	
	func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
		guard user != nil else { return }
		
		DispatchQueue.main.async { [weak self] in
			guard error == nil else {
				if (error as NSError).code == GIDSignInErrorCode.hasNoAuthInKeychain.rawValue {
					self?.showErrorAlert(message: "The user has not signed in before or they have since signed out.")
				} else {
					self?.showErrorAlert(message: "Google Login: \(error.localizedDescription)")
				}
				
				return
			}
			
			settings.userName	= nil
			let credentials		= Credentials.google(serverAuthCode: user.serverAuthCode)
			
			app.login(credentials: credentials) { [weak self] maybeUser, error in
				DispatchQueue.main.async {
					guard error == nil else {
						self?.showErrorAlert(message: "Login failed: \(error!.localizedDescription)")
						return
					}
					
					guard maybeUser != nil else {
						self?.showErrorAlert(message: "Invalid User")
						return
					}
					
					self?.authType	= .google
					self?.dismiss(animated: true) { [weak self] in
						self?.coordinator?.loginCompleted()
					}
				}
			}
		}
	}
	
	func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!,
	          withError error: Error!)
	{
		guard user != nil else { return }
		
		print("Disconnecting \(String(describing: user!.profile.email))")
	}
}
