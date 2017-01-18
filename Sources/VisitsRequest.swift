//
//  VisitsRequest.swift
//  SwiftLocation
//
//  Created by Daniele Margutti on 18/01/2017.
//  Copyright © 2017 Daniele Margutti. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit


/// Callback for Visit requests
///
/// - onDidVisit: callback called when a new visit is generated
/// - onError: callback called on error
public enum VisitCallback {
	public typealias onVisit = ((CLVisit) -> (Void))
	public typealias onFailure = ((Error) -> (Void))
	
	case onDidVisit(_: Context, _: onVisit)
	case onError(_: Context, _: onFailure)
}

public class VisitsRequest: Request {
	
	/// Returns a Boolean value indicating whether two values are equal.
	///
	/// Equality is the inverse of inequality. For any values `a` and `b`,
	/// `a == b` implies that `a != b` is `false`.
	///
	/// - Parameters:
	///   - lhs: A value to compare.
	///   - rhs: Another value to compare.
	public static func ==(lhs: VisitsRequest, rhs: VisitsRequest) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}

	
	/// Unique identifier of the request
	private var identifier = NSUUID().uuidString
	
	public var cancelOnError: Bool = false
	
	/// Hash value for Hashable protocol
	public var hashValue: Int {
		return identifier.hash
	}
	
	/// Callback to call when request's state did change
	public var onStateChange: ((_ old: RequestState, _ new: RequestState) -> (Void))?
	
	private var registeredCallbacks: [VisitCallback] = []
	
	/// This represent the current state of the Request
	internal var _previousState: RequestState = .idle
	internal(set) var _state: RequestState = .idle {
		didSet {
			if _previousState != _state {
				onStateChange?(_previousState,_state)
				_previousState = _state
			}
		}
	}
	public var state: RequestState {
		get {
			return self._state
		}
	}
	
	public var requiredAuth: Authorization {
		return .always
	}
	
	/// Initialize a new visit request.
	/// Visit objects contain as much information about the visit as possible but may not always include both the arrival
	/// and departure times. For example, when the user arrives at a location, the system may send an event with only an arrival time. When 
	/// the user departs a location, the event can contain both the arrival time (if your app was monitoring visits prior to the user’s 
	/// arrival) and the departure time.
	///
	/// - Parameters:
	///   - event: callback called when a new visit is generated
	///   - error: callback called when an error is thrown
	/// - Throws: throw an exception if application is not configured correctly to receive Visits events. App should
	///           require always authorization.
	public init(event: @escaping VisitCallback.onVisit, error: @escaping VisitCallback.onFailure) throws {
		guard CLLocationManager.appAuthorization == .always else {
			throw LocationError.other("NSLocationAlwaysUsageDescription in Info.plist is required to use Visits feature")
		}
		self.register(callback: VisitCallback.onDidVisit(.main, event))
		self.register(callback: VisitCallback.onError(.main, error))
	}
	
	/// Register a new callback for this request
	///
	/// - Parameter callback: callback to register
	public func register(callback: VisitCallback?) {
		guard let callback = callback else { return }
		self.registeredCallbacks.append(callback)
	}
	
	/// Pause events dispatch for this request
	public func pause() {
		Location.pause(self)
	}
	
	/// Resume events dispatch for this request
	public func resume() {
		Location.start(self)
	}
	
	/// Cancel events dispatch for this request
	public func cancel() {
		Location.cancel(self)
	}
	
	public func onResume() {
		
	}
	
	public func onPause() {
		
	}
	
	public func onCancel() {
		
	}
	
	public var isBackgroundRequest: Bool {
		return true
	}
	
	/// Dispatch CLVisit object to registered callbacks
	///
	/// - Parameter visit: visited object
	internal func dispatch(visit: CLVisit) {
		self.registeredCallbacks.forEach {
			if case .onDidVisit(let context, let handler) = $0 {
				context.queue.async {
					handler(visit)
				}
			}
		}
	}
	
	
	/// Dispatch error to registered callbacks
	///
	/// - Parameter error: error
	public func dispatch(error: Error) {
		self.registeredCallbacks.forEach {
			if case .onError(let context, let handler) = $0 {
				context.queue.async {
					handler(error)
				}
			}
		}
		
		if self.cancelOnError == true { // remove from main location queue
			self.cancel()
			self._state = .failed
		}
	}
	
}
