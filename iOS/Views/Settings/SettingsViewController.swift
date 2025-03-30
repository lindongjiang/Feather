//
//  SettingsViewController.swift
//  mantou
//
//  Created by samara on 7/7/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import UIKit
import Nuke
import SwiftUI

class SettingsViewController: FRSTableViewController {
	// 社交链接数据
	var socialLinks: [String: String] = [:]
	var socialLinkKeys: [String] = []
	
	let aboutSection = [
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Mantou")
	]

	let displaySection = [
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"),
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON")
	]

	let certificateSection = [
		"Current Certificate",
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"),
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"),
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS")
	]

	let logsSection = [
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS")
	]

	let foldersSection = [
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"),
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER")
	]

	let resetSection = [
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"),
		String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL")
	]
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// 加载社交链接数据
		loadSocialLinks()
		
		tableData = {
			return [
				socialLinkKeys,
				aboutSection,
				displaySection,
				certificateSection,
				logsSection,
				foldersSection,
				resetSection
			]
		}()
		
		
		sectionTitles =
		[
			"社区链接",
			"",
			"",
			"",
			"",
			"",
			"",
		]
		ensureTableDataHasSections()
		setupNavigation()
	}
	
	private func loadSocialLinks() {
		guard let url = URL(string: "https://uni.cloudmantoub.online/mantou.json") else { return }
		
		let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self = self, 
				  let data = data,
				  error == nil else {
				Debug.shared.log(message: "Error fetching social links: \(error?.localizedDescription ?? "Unknown error")")
				return
			}
			
			do {
				if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
				   let links = json["social_links"] as? [String: String] {
					DispatchQueue.main.async {
						self.socialLinks = links
						self.socialLinkKeys = Array(links.keys)
						self.tableData[0] = self.socialLinkKeys
						self.tableView.reloadData()
					}
				}
			} catch {
				Debug.shared.log(message: "Error parsing social links: \(error.localizedDescription)")
			}
		}
		
		task.resume()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.tableView.reloadData()
	}

	fileprivate func setupNavigation() {
		self.title = String.localized("TAB_SETTINGS")
	}
}

extension SettingsViewController {
	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 0 {
			return "社区交流平台"
		}
		
		switch section {
		case sectionTitles.count - 1: return "本项目给予github开源项目Feather • SideStore 二开 • Mantou \(AppDelegate().logAppVersionInfo()) • iOS \(UIDevice.current.systemVersion)"
		default:
			return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let reuseIdentifier = "Cell"
		var cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
		cell.accessoryType = .none
		cell.selectionStyle = .none
		
		let cellText = tableData[indexPath.section][indexPath.row]
		cell.textLabel?.text = cellText
		
		// 社交链接部分
		if indexPath.section == 0 {
			cell.textLabel?.textColor = .tintColor
			cell.setAccessoryIcon(with: "link")
			cell.selectionStyle = .default
			return cell
		}
		
		switch cellText {
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Mantou"):
			cell.setAccessoryIcon(with: "info.circle")
			cell.selectionStyle = .default
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"):
			cell.setAccessoryIcon(with: "paintbrush")
			cell.selectionStyle = .default
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON"):
			cell.setAccessoryIcon(with: "app.dashed")
			cell.selectionStyle = .default
			
		case "Current Certificate":
			if let hasGotCert = CoreDataManager.shared.getCurrentCertificate() {
				let cell = CertificateViewTableViewCell()
				cell.configure(with: hasGotCert, isSelected: false)
				cell.selectionStyle = .none
				return cell
			} else {
				cell.textLabel?.text = String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CURRENT_CERTIFICATE_NOSELECTED")
				cell.textLabel?.textColor = .secondaryLabel
				cell.selectionStyle = .none
			}
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"):
			cell.setAccessoryIcon(with: "plus")
			cell.selectionStyle = .default
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"):
			cell.setAccessoryIcon(with: "signature")
			cell.selectionStyle = .default
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS"):
			cell.setAccessoryIcon(with: "server.rack")
			cell.selectionStyle = .default
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS"):
			cell.setAccessoryIcon(with: "newspaper")
			cell.selectionStyle = .default
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"),
			String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER"):
			cell.accessoryType = .disclosureIndicator
			cell.textLabel?.textColor = .tintColor
			cell.selectionStyle = .default
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"), 
			String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"):
			cell.textLabel?.textColor = .tintColor
			cell.accessoryType = .disclosureIndicator
			cell.selectionStyle = .default
			
		default:
			break
		}
		
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let itemTapped = tableData[indexPath.section][indexPath.row]
		
		// 处理社交链接点击
		if indexPath.section == 0, let linkURL = socialLinks[itemTapped] {
			if let url = URL(string: linkURL) {
				UIApplication.shared.open(url, options: [:], completionHandler: nil)
			}
			tableView.deselectRow(at: indexPath, animated: true)
			return
		}
		
		switch itemTapped {
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Mantou"):
			let l = AboutViewController()
			navigationController?.pushViewController(l, animated: true)
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"):
			let l = DisplayViewController()
			navigationController?.pushViewController(l, animated: true)
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON"):
			let l = IconsListViewController()
			navigationController?.pushViewController(l, animated: true)
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"):
			let l = CertificatesViewController()
			navigationController?.pushViewController(l, animated: true)
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"):
			let signingDataWrapper = SigningDataWrapper(signingOptions: UserDefaults.standard.signingOptions)
			let l = SigningsOptionViewController(signingDataWrapper: signingDataWrapper)
			navigationController?.pushViewController(l, animated: true)
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS"):
			let l = ServerOptionsViewController()
			navigationController?.pushViewController(l, animated: true)
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS"):
			let l = LogsViewController()
			navigationController?.pushViewController(l, animated: true)
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"):
			openDirectory(named: "Apps")
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER"):
			openDirectory(named: "Certificates")
			
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"):
			self.resetOptionsAction()
		case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"):
			self.resetAllAction()
		default:
			break
		}
		
		tableView.deselectRow(at: indexPath, animated: true)
	}
	
}

extension UITableViewCell {
	func setAccessoryIcon(with symbolName: String, tintColor: UIColor = .tertiaryLabel, renderingMode: UIImage.RenderingMode = .alwaysOriginal) {
		if let image = UIImage(systemName: symbolName)?.withTintColor(tintColor, renderingMode: renderingMode) {
			let imageView = UIImageView(image: image)
			self.accessoryView = imageView
		} else {
			self.accessoryView = nil
		}
	}
}

extension SettingsViewController {
	fileprivate func openDirectory(named directoryName: String) {
		let directoryURL = getDocumentsDirectory().appendingPathComponent(directoryName)
		let path = directoryURL.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")
		
		UIApplication.shared.open(URL(string: path)!, options: [:]) { success in
			if success {
				Debug.shared.log(message: "File opened successfully.")
			} else {
				Debug.shared.log(message: "Failed to open file.")
			}
		}
	}
}

