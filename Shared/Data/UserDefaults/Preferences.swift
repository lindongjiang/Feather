//
//  Preferences.swift
//  mantou
//
//  Created by samara on 5/17/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import Foundation
import UIKit

enum Preferences {
	static var installPathChangedCallback: ((String?) -> Void)?
	static let defaultInstallPath: String = "https://api.palera.in"
	
	@Storage(key: "Mantou.UserSpecifiedOnlinePath", defaultValue: defaultInstallPath)
	static var onlinePath: String? { didSet { installPathChangedCallback?(onlinePath) } }
	
	@Storage(key: "Mantou.UserSelectedServer", defaultValue: false)
	static var userSelectedServer: Bool
	
	@Storage(key: "Mantou.DefaultRepos", defaultValue: false)
	// Default repo is from the repository
	static var defaultRepos: Bool
	
	@Storage(key: "Mantou.AppUpdates", defaultValue: false)
	// Default repo is from the repository
	static var appUpdates: Bool
	
	@Storage(key: "Mantou.gotSSLCerts", defaultValue: false)
	static var gotSSLCerts: Bool
	
	@Storage(key: "Mantou.BDefaultRepos", defaultValue: false)
	// Default beta repo is from the repository
	static var bDefaultRepos: Bool
	
	@Storage(key: "Mantou.userIntefacerStyle", defaultValue: UIUserInterfaceStyle.unspecified.rawValue)
	static var preferredInterfaceStyle: Int
	
	@CodableStorage(key: "Mantou.AppTintColor", defaultValue: CodableColor(UIColor(hex: "848ef9")))
	static var appTintColor: CodableColor
	
	@Storage(key: "Mantou.OnboardingActive", defaultValue: true)
	static var isOnboardingActive: Bool
	
	@Storage(key: "Mantou.selectedCert", defaultValue: 0)
	static var selectedCert: Int
	
	@Storage(key: "Mantou.ppqcheckBypass", defaultValue: "")
	// random string
	static var pPQCheckString: String
	
	@Storage(key: "Mantou.CertificateTitleAppIDtoTeamID", defaultValue: false)
	static var certificateTitleAppIDtoTeamID: Bool
	
	@Storage(key: "Mantou.AppDescriptionAppearence", defaultValue: 0)
	// 0 == Default appearence
	// 1 == Replace subtitle with localizedDescription
	// 2 == Move localizedDescription below app icon, and above screenshots
	static var appDescriptionAppearence: Int
	
	@Storage(key: "UserPreferredLanguageCode", defaultValue: nil, callback: preferredLangChangedCallback)
	/// Preferred language
	static var preferredLanguageCode: String?
	
	@Storage(key: "Mantou.Beta", defaultValue: false)
	//
	static var beta: Bool
	
	@CodableStorage(key: "SortOption", defaultValue: SortOption.default)
	static var currentSortOption: SortOption
	
	@Storage(key: "SortOptionAscending", defaultValue: true)
	static var currentSortOptionAscending: Bool
}

// MARK: - Callbacks
fileprivate extension Preferences {
	static func preferredLangChangedCallback(newValue: String?) {
		Bundle.preferredLocalizationBundle = .makeLocalizationBundle(preferredLanguageCode: newValue)
	}
}
// MARK: - Color

struct CodableColor: Codable {
	let red: CGFloat
	let green: CGFloat
	let blue: CGFloat
	let alpha: CGFloat
	
	var uiColor: UIColor {
		return UIColor(red: self.red, green: self.green, blue: self.blue, alpha: self.alpha)
	}
	
	init(_ color: UIColor) {
		var _red: CGFloat = 0, _green: CGFloat = 0, _blue: CGFloat = 0, _alpha: CGFloat = 0
		
		color.getRed(&_red, green: &_green, blue: &_blue, alpha: &_alpha)
		
		self.red = _red
		self.blue = _blue
		self.green = _green
		self.alpha = _alpha
	}
}

