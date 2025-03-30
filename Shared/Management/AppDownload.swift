//
//  AppDownload.swift
//  mantou
//
//  Created by samara on 6/29/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import Foundation
import ZIPFoundation
import UIKit
import CoreData

// 确保Archive类型可用于错误处理
typealias Archive = ZIPFoundation.Archive

class AppDownload: NSObject {
	let progress = Progress(totalUnitCount: 100)
	var dldelegate: DownloadDelegate?
	var downloads = [URLSessionDownloadTask: (uuid: String, appuuid: String, destinationUrl: URL, completion: (String?, String?, Error?) -> Void)]()
	var DirectoryUUID: String?
	var AppUUID: String?
	private var downloadTask: URLSessionDownloadTask?
	private var session: URLSession?

	func downloadFile(url: URL, appuuid: String, completion: @escaping (String?, String?, Error?) -> Void) {
		let uuid = UUID().uuidString
		self.DirectoryUUID = uuid
		self.AppUUID = appuuid
		guard let folderUrl = createUuidDirectory(uuid: uuid) else {
			completion(nil, nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create directory"]))
			return
		}

		let destinationUrl = folderUrl.appendingPathComponent(url.lastPathComponent)
		let sessionConfig = URLSessionConfiguration.default
		session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
		downloadTask = session?.downloadTask(with: url)

		downloads[downloadTask!] = (uuid: uuid, appuuid: appuuid, destinationUrl: destinationUrl, completion: completion)
		downloadTask!.resume()
	}
	
	func importFile(url: URL, uuid: String, completion: @escaping (URL?, Error?) -> Void) {
		guard let folderUrl = createUuidDirectory(uuid: uuid) else {
			completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create directory"]))
			return
		}
		
		let fileName = url.lastPathComponent
		let destinationUrl = folderUrl.appendingPathComponent(fileName)
		
		do {
			let fileManager = FileManager.default
			try fileManager.moveItem(at: url, to: destinationUrl)
			completion(destinationUrl, nil)
		} catch {
			completion(nil, error)
		}
	}


	func cancelDownload() {
		Debug.shared.log(message: "AppDownload.cancelDownload: User cancelled the download", type: .info)
		downloadTask?.cancel()
		session?.invalidateAndCancel()
		downloadTask = nil
		session = nil
		progress.cancel()
	}

	func createUuidDirectory(uuid: String) -> URL? {
		let baseFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		let folderUrl = baseFolder.appendingPathComponent("Apps/Unsigned").appendingPathComponent(uuid)

		do {
			try FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
			return folderUrl
		} catch {
			return nil
		}
	}
	
	func extractCompressedBundle(packageURL: String, completion: @escaping (String?, Error?) -> Void) {
		let fileURL = URL(fileURLWithPath: packageURL)
		let destinationURL = fileURL.deletingLastPathComponent()
		let fileManager = FileManager.default

		if !fileManager.fileExists(atPath: fileURL.path) {
			completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "文件不存在"]))
			return
		}

		do {
			// 创建一个专门的进度监控器
			let unzipProgress = Progress(totalUnitCount: 100)
			
			// 使用安全的错误处理方式进行解压
			do {
				try fileManager.unzipItem(at: fileURL, to: destinationURL, progress: unzipProgress)
			} catch let zipError as Archive.ArchiveError where zipError._code == 5 {
				// 特殊处理取消操作错误(错误代码5)
				Debug.shared.log(message: "解压操作被取消", type: .info)
				try? fileManager.removeItem(at: destinationURL)
				cancelDownload()
				completion(nil, NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "解压操作被取消"]))
				return
			} catch {
				// 处理其他解压错误
				Debug.shared.log(message: "解压失败: \(error.localizedDescription)", type: .error)
				try? fileManager.removeItem(at: destinationURL)
				completion(nil, error)
				return
			}
			
			// 检查进度是否被取消
			if unzipProgress.isCancelled || progress.isCancelled {
				if fileManager.fileExists(atPath: destinationURL.path) {
					try? fileManager.removeItem(at: destinationURL)
				}
				cancelDownload()
				completion(nil, NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "操作被取消"]))
				return
			}

			// 尝试删除原始IPA文件
			do {
				try fileManager.removeItem(at: fileURL)
			} catch {
				Debug.shared.log(message: "无法删除原始IPA文件: \(error.localizedDescription)", type: .warning)
				// 继续处理，这不是关键错误
			}
			
			// 安全处理Payload文件夹
			let payloadURL = destinationURL.appendingPathComponent("Payload")
			if !fileManager.fileExists(atPath: payloadURL.path) {
				Debug.shared.log(message: "Payload文件夹不存在", type: .error)
				completion(nil, NSError(domain: "", code: 2, userInfo: [NSLocalizedDescriptionKey: "解压后未找到Payload文件夹"]))
				return
			}
			
			do {
				let contents = try fileManager.contentsOfDirectory(at: payloadURL, includingPropertiesForKeys: nil, options: [])
				
				if let appDirectory = contents.first(where: { $0.pathExtension == "app" }) {
					let sourceURL = appDirectory
					let targetURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
					
					// 如果目标已存在，先删除
					if fileManager.fileExists(atPath: targetURL.path) {
						try fileManager.removeItem(at: targetURL)
					}
					
					// 移动app目录
					try fileManager.moveItem(at: sourceURL, to: targetURL)
					
					// 删除Payload文件夹
					try fileManager.removeItem(at: payloadURL)
					
					// 删除签名信息
					let codeSignatureDirectory = targetURL.appendingPathComponent("_CodeSignature")
					if fileManager.fileExists(atPath: codeSignatureDirectory.path) {
						try fileManager.removeItem(at: codeSignatureDirectory)
						Debug.shared.log(message: "已删除_CodeSignature目录")
					}
					
					completion(targetURL.path, nil)
				} else {
					Debug.shared.log(message: "在Payload中未找到.app目录", type: .error)
					completion(nil, NSError(domain: "", code: 3, userInfo: [NSLocalizedDescriptionKey: "在Payload中未找到.app目录"]))
				}
			} catch {
				Debug.shared.log(message: "处理应用目录时出错: \(error.localizedDescription)", type: .error)
				completion(nil, error)
			}
			
		} catch {
			Debug.shared.log(message: "解压过程发生错误: \(error)", type: .error)
			if fileManager.fileExists(atPath: destinationURL.path) {
				try? fileManager.removeItem(at: destinationURL)
			}
			cancelDownload()
			completion(nil, error)
		}
	}



	func addToApps(bundlePath: String, uuid: String, sourceLocation: String? = nil, completion: @escaping (Error?) -> Void) {
		guard let bundle = Bundle(path: bundlePath) else {
			let error = NSError(domain: "Feather", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load bundle at \(bundlePath)"])
			completion(error)
			return
		}

		if let infoDict = bundle.infoDictionary {

			var iconURL = ""
			if let iconsDict = infoDict["CFBundleIcons"] as? [String: Any],
			   let primaryIconsDict = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
			   let iconFiles = primaryIconsDict["CFBundleIconFiles"] as? [String],
			   let iconFileName = iconFiles.first,
			   let iconPath = bundle.path(forResource: iconFileName + "@2x", ofType: "png") {
				iconURL = "\(URL(string: iconPath)?.lastPathComponent ?? "")"
			}

			CoreDataManager.shared.addToDownloadedApps(
				version: (infoDict["CFBundleShortVersionString"] as? String)!,
				name: (infoDict["CFBundleDisplayName"] as? String ?? infoDict["CFBundleName"] as? String)!,
				bundleidentifier: (infoDict["CFBundleIdentifier"] as? String)!,
				iconURL: iconURL,
				uuid: uuid,
				appPath: "\(URL(string: bundlePath)?.lastPathComponent ?? "")", 
				sourceLocation: sourceLocation) {_ in
			}

			completion(nil)
		} else {
			let error = NSError(domain: "Feather", code: 3, userInfo: [NSLocalizedDescriptionKey: "Info.plist not found in bundle at \(bundlePath)"])
			completion(error)
		}
	}
}

extension AppDownload: URLSessionDownloadDelegate {
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		guard let download = downloads[downloadTask] else {
			return
		}
		let fileManager = FileManager.default
		do {
			try fileManager.moveItem(at: location, to: download.destinationUrl)
			download.completion(download.uuid, download.destinationUrl.path, nil)
		} catch {
			download.completion(download.uuid, download.destinationUrl.path, error)
		}
		downloads.removeValue(forKey: downloadTask)
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard let download = downloads[task as! URLSessionDownloadTask] else {
			return
		}
		if let error = error {
			download.completion(download.uuid, download.destinationUrl.path, error)
		}
		downloads.removeValue(forKey: task as! URLSessionDownloadTask)
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		let progress = CGFloat(totalBytesWritten) / CGFloat(totalBytesExpectedToWrite)
		if let uuid = downloads[downloadTask]?.appuuid {
			dldelegate?.updateDownloadProgress(progress: progress, uuid: uuid)
		}
	}
}
enum HandleIPAFileError: Error {
	case importFailed(String)
	case extractionFailed(String)
	case additionFailed(String)
}

func handleIPAFile(destinationURL: URL, uuid: String, dl: AppDownload) throws {
	let semaphore = DispatchSemaphore(value: 0)
	
	var functionError: Error? = nil
	var newUrl: URL? = nil
	var targetBundle: String? = nil
	
	DispatchQueue(label: "DL").async {
		dl.importFile(url: destinationURL, uuid: uuid) { resultUrl, error in
			if let error = error {
				functionError = HandleIPAFileError.importFailed(error.localizedDescription)
				semaphore.signal()
				return
			}
			
			newUrl = resultUrl
			
			guard let validNewUrl = newUrl else {
				functionError = HandleIPAFileError.importFailed("导入未返回有效URL")
				semaphore.signal()
				return
			}
			
			dl.extractCompressedBundle(packageURL: validNewUrl.path) { bundle, error in
				if let error = error {
					// 检查是否为取消操作错误
					let errorDescription = error.localizedDescription
					if errorDescription.contains("cancelledOperation") || 
                       errorDescription.contains("取消") || 
                       errorDescription.contains("cancelled") {
						functionError = HandleIPAFileError.extractionFailed("操作已取消")
					} else if errorDescription.contains("ZIPFoundation.Archive.ArchiveError") {
						// 特殊处理ZIP错误
						functionError = HandleIPAFileError.extractionFailed("解压缩文件时出错: \(errorDescription)")
					} else {
						functionError = HandleIPAFileError.extractionFailed(errorDescription)
					}
					semaphore.signal()
					return
				}
				
				targetBundle = bundle
				
				guard let validTargetBundle = targetBundle else {
					functionError = HandleIPAFileError.extractionFailed("解压缩后未返回有效应用目录")
					semaphore.signal()
					return
				}
				
				dl.addToApps(bundlePath: validTargetBundle, uuid: uuid, sourceLocation: "Imported") { error in
					if let error = error {
						functionError = HandleIPAFileError.additionFailed(error.localizedDescription)
					}
					
					semaphore.signal()
				}
			}
		}
	}
	
	// 添加超时处理，避免无限等待
	let result = semaphore.wait(timeout: .now() + 300) // 5分钟超时
	
	if result == .timedOut {
		// 处理超时情况
		DispatchQueue.main.async {
			Debug.shared.log(message: "操作超时", type: .error)
		}
		throw HandleIPAFileError.extractionFailed("操作超时，请重试")
	}
	
	if let error = functionError {
		DispatchQueue.main.async {
			Debug.shared.log(message: error.localizedDescription, type: .error)
		}
		throw error
	} else {
		DispatchQueue.main.async {
			Debug.shared.log(message: "完成！", type: .success)
			NotificationCenter.default.post(name: Notification.Name("lfetch"), object: nil)
		}
	}
}
