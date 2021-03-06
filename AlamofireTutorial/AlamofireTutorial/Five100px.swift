//
//  Five100px.swift
//  AlamofireTutorial
//
//  Created by Wei Jun Fan on 22/09/15.
//  Copyright © 2015年 ixfan. All rights reserved.
//

import Foundation
import Alamofire

public protocol ResponseObjectSerializable {
	init?(response: NSHTTPURLResponse, representation: AnyObject)
}

public protocol ResponseCollectionSerializable {
	static func collection(response response: NSHTTPURLResponse, representation: AnyObject) -> [Self]
}

extension Alamofire.Request {
	public func responseObject<T: ResponseObjectSerializable>(completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<T>) -> Void) -> Self {
		let responseSerializer = GenericResponseSerializer { (request, response, data) -> Result<T> in
			let JSONResponseSerializer = Request.JSONResponseSerializer(options: NSJSONReadingOptions.AllowFragments)
			let result = JSONResponseSerializer.serializeResponse(request, response, data)
			
			guard let resp = response where result.isSuccess else {
				return Result.Failure(data, result.error!)
			}
			
			return Result.Success(T(response: resp, representation: result.value!)!)
		}
		
		return response(responseSerializer: responseSerializer, completionHandler: completionHandler)
	}
}

extension Alamofire.Request {
	public func responseCollection<T: ResponseCollectionSerializable>(completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<[T]>) -> Void) -> Self {
		let responseSerializer = GenericResponseSerializer { (request, response, data) -> Result<[T]> in
			let JSONResponseSerializer = Request.JSONResponseSerializer(options: .AllowFragments)
			let result = JSONResponseSerializer.serializeResponse(request, response, data)
			
			guard let resp = response where result.isSuccess else {
				return Result.Failure(data, result.error!)
			}
			
			return Result.Success(T.collection(response: resp, representation: result.value!))
		}
		
		return response(responseSerializer: responseSerializer, completionHandler: completionHandler)
	}
}

extension Alamofire.Request {
	public static func imageResponseSerializer() -> GenericResponseSerializer<UIImage> {
		return GenericResponseSerializer(serializeResponse: { (request, response, data) -> Result<UIImage> in
			guard data != nil else {
				return Result.Failure(data, NSError(domain: "com.xxx.AlamofireTutorial", code: -70001, userInfo: nil))
			}
			
			let image = UIImage(data: data!, scale: UIScreen.mainScreen().scale)
			
			return Result.Success(image!)
		})
	}
	
	public func responseImage(completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<UIImage>) -> Void) -> Self {
		return response(responseSerializer: Request.imageResponseSerializer(), completionHandler: completionHandler)
	}
}

struct Five100px {
	// See the document on [photo sizes](https://github.com/500px/api-documentation/blob/master/basics/formats_and_terms.md#image-urls-and-image-sizes)
	enum ImageSize: Int {
		case Tiny = 1
		case Small = 2
		case Medium = 3
		case Large = 4
		case XLarge = 5
		case MediumUncropped = 30
	}
	
	enum Router: URLRequestConvertible {
		static let baseURLString = "https://api.500px.com/v1"
		static let consumerKey = "qzzP3JPuDIUzD9GiiXKE8mhq1Cw6GNj06p3PbEGz"
		// "****_your_consumer_key_****"
		
		case PopularPhotos(Int)
		case PhotoInfo(Int, ImageSize)
		case Comments(Int, Int)
		
		var URLRequest: NSMutableURLRequest {
			let requestInfo: (path: String, parameters: [String: AnyObject]) = {
				switch self {
				case .PopularPhotos(let page):
					let params = ["consumer_key":Router.consumerKey, "page":"\(page)", "feature":"popular", "image_size":"\(ImageSize.MediumUncropped.rawValue)", "rpp":"50", "include_store":"store_download", "include_states":"votes"]
					return ("/photos", params)
				case .PhotoInfo(let photoID, let imageSize):
					let params = ["consumer_key":Router.consumerKey, "image_size":"\(imageSize.rawValue)"]
					return ("/photos/\(photoID)", params)
				case .Comments(let photoID, let commentsPage):
					let params = ["consumer_key":Router.consumerKey, "comments":"1", "comments_page":"\(commentsPage)"]
					return ("/photos/\(photoID)/comments", params)
				}
			}()
			
			let URL = NSURL(string: Router.baseURLString)
			let URLRequest = NSURLRequest(URL: URL!.URLByAppendingPathComponent(requestInfo.path))
			let encoding = Alamofire.ParameterEncoding.URL
			
			return encoding.encode(URLRequest, parameters: requestInfo.parameters).0
		}
	}
}

class PhotoInfo: NSObject, ResponseObjectSerializable {
	let id: Int
	let url: String
	
	var size: CGSize?
	
	var name: String?
	
	var favoritesCount: Int?
	var votesCount: Int?
	var commentsCount: Int?
	
	var highest: Float?
	var pulse: Float?
	var views: Int?
	var camera: String?
	var desc: String?
	
	init(id: Int, url: String) {
		self.id = id
		self.url = url
	}
	
	required init(response: NSHTTPURLResponse, representation: AnyObject) {
		self.id = representation.valueForKeyPath("photo.id") as! Int
		self.url = representation.valueForKeyPath("photo.image_url") as! String
		
		self.favoritesCount = representation.valueForKeyPath("photo.favorites_count") as? Int
		self.votesCount = representation.valueForKeyPath("photo.votes_count") as? Int
		self.commentsCount = representation.valueForKeyPath("photo.comments_count") as? Int
		self.highest = representation.valueForKeyPath("photo.highest_rating") as? Float
		self.pulse = representation.valueForKeyPath("photo.rating") as? Float
		self.views = representation.valueForKeyPath("photo.times_viewed") as? Int
		self.camera = representation.valueForKeyPath("photo.camera") as? String
		self.desc = representation.valueForKeyPath("photo.description") as? String
		self.name = representation.valueForKeyPath("photo.name") as? String
	}
	
	convenience init(id: Int, url: String, width: Float?, height: Float?) {
		self.init(id: id, url: url)
		
		if let width = width, height = height {
			self.size = CGSize(width: CGFloat(width), height: CGFloat(height))
		}
	}
	
	override func isEqual(object: AnyObject!) -> Bool {
		return (object as! PhotoInfo).id == self.id
	}
	
	override var hash: Int {
		return (self as PhotoInfo).id
	}
}

final class Comment: ResponseCollectionSerializable {
	let userFullname: String
	let userPictureURL: String
	let commentBody: String
	
	init(JSON: AnyObject) {
		userFullname = JSON.valueForKeyPath("user.fullname") as! String
		userPictureURL = JSON.valueForKeyPath("user.userpic_url") as! String
		commentBody = JSON.valueForKeyPath("body") as! String
	}
	
	static func collection(response response: NSHTTPURLResponse, representation: AnyObject) -> [Comment] {
		var comments = [Comment]()
		
		for JSONComment in representation.valueForKey("comments") as! [NSDictionary] {
			comments.append(Comment(JSON: JSONComment))
		}
		
		return comments
	}
}