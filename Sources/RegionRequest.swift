//
//  RegionRequest.swift
//  SwiftLocation
//
//  Created by Daniele Margutti on 17/01/2017.
//  Copyright © 2017 Daniele Margutti. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit


/// Callback
///
/// - onEnter: callback called when entering in region
/// - onExit: callback called when exiting from region
/// - onError: callback called on error
public enum RegionCallback {
	public typealias onEvent = ((Void) -> (Void))
	public typealias onFailure = ((Error) -> (Void))

	case onEnter(_: Context, _: onEvent)
	case onExit(_: Context, _: onEvent)
	case onError(_: Context, _: onFailure)
	
	
	/// ‘true‘ if event represent a region enter
	internal var isEnterEvent: Bool {
		switch self {
		case .onEnter(_, _):	return true
		default:				return false
		}
	}
	
	/// `false` if event represent a region exit
	internal var isExitEvent: Bool {
		switch self {
		case .onExit(_, _):	return true
		default:				return false
		}
	}
}


/// Region event
///
/// - entered: entered in region
/// - exited: exited from region
public enum RegionEvent {
	case entered
	case exited
}

public class RegionRequest: Request {
	
	/// Callback to call when request's state did change
	public var onStateChange: ((_ old: RequestState, _ new: RequestState) -> (Void))?
	
	/// Registered callbacks
	private var registeredCallbacks: [RegionCallback] = []
	
	/// Callback called when monitoring for this region starts
	public var onStartMonitoring: ((Void) -> (Void))? = nil
	
	public typealias DetermineStateCallback = ((CLRegionState) -> (Void))
	private var stateCallback: DetermineStateCallback? = nil
	
	/// Region to monitor
	private(set) var region: CLCircularRegion
	
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
	
	public var isBackgroundRequest: Bool {
		return true
	}
	
	/// Returns a Boolean value indicating whether two values are equal.
	///
	/// Equality is the inverse of inequality. For any values `a` and `b`,
	/// `a == b` implies that `a != b` is `false`.
	///
	/// - Parameters:
	///   - lhs: A value to compare.
	///   - rhs: Another value to compare.
	public static func ==(lhs: RegionRequest, rhs: RegionRequest) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}

	/// Unique identifier of the request
	private var identifier = NSUUID().uuidString
	
	/// Remove request if an error occours
	public var cancelOnError: Bool = false
	
	/// Hash value for Hashable protocol
	public var hashValue: Int {
		return identifier.hash
	}
	
	/// Initialize a new region monitoring request to monitor a region with given center and radius
	///
	/// - Parameters:
	///   - region: region to monitor
	///   - enter: callback to call when entering in region
	///   - exit: callback to call when exiting from region
	///   - error: callback to call on error
	/// - Throws: throw an exception if configuration or hardware is not valid to use region monitoring
	public init(region: CLCircularRegion,
	            onEnter enter: RegionCallback.onEvent?, onExit exit: RegionCallback.onEvent?, error: RegionCallback.onFailure?) throws {
		
		try RegionRequest.validateConfiguration()
		
		self.region = region
		if enter != nil { self.add(callback: .onEnter(.main, enter!)) }
		if exit != nil { self.add(callback: .onExit(.main, exit!)) }
		if error != nil { self.add(callback: .onError(.main, error!)) }
	}
	
	
	/// Initialize a new region monitoring request to monitor a region with given center and radius
	///
	/// - Parameters:
	///   - center: center coordinates
	///   - radius: radius in meters
	///   - enter: callback to call when entering in region
	///   - exit: callback to call when exiting from region
	///   - error: callback to call on error
	/// - Throws: throw an exception if configuration or hardware is not valid to use region monitoring
	public init(center: CLLocationCoordinate2D, radius: CLLocationDistance,
	            onEnter enter: RegionCallback.onEvent?, onExit exit: RegionCallback.onEvent?, error: RegionCallback.onFailure?) throws {
		
		try RegionRequest.validateConfiguration()
		
		self.region = CLCircularRegion(center: center, radius: radius, identifier: self.identifier)
		if enter != nil { self.add(callback: .onEnter(.main, enter!)) }
		if exit != nil { self.add(callback: .onExit(.main, exit!)) }
		if error != nil { self.add(callback: .onError(.main, error!)) }
	}
	
	
	/// Validate hardware and software configuration in order to use this service.
	///
	/// - Throws: Throw an exception if hardware or software configuration are not set properly
	private class func validateConfiguration() throws {
		guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
			throw LocationError.serviceNotAvailable
		}
		guard CLLocationManager.appAuthorization == .always else {
			throw LocationError.other("NSLocationAlwaysUsageDescription in Info.plist is required to use Region Monitoring feature")
		}
	}
	
	private func add(callback: RegionCallback?) {
		guard let callback = callback else { return }
		registeredCallbacks.append(callback)
		self.updateNotifications()
	}
	
	/// `true` if request is on location queue
	internal var isInQueue: Bool {
		return Location.isQueued(self) == true
	}
	
	
	/// Retrieves the state of a region asynchronously.
	/// Multiple call of this func cancel previous requests.
	///
	/// - Parameter callback: callback to return at the end of the operation
	/// - Returns: `false` if region is not queued or currently running
	public func determineState(_ callback: @escaping DetermineStateCallback) -> Bool {
		guard self.isInQueue, self.state.isRunning else {
			return false
		}
		self.stateCallback = callback
		Location.locationManager.requestState(for: self.region)
		return true
	}
	
	
	/// Update region notification event to enable/disable notification on exit or enter
	private func updateNotifications() {
		var hasOnEnterNotify = false
		var hasOnExitNotify = false
		for callback in registeredCallbacks {
			if case .onEnter(_,_) = callback { hasOnEnterNotify = true }
			if case .onExit(_,_) = callback { hasOnExitNotify = true }
		}
		
		region.notifyOnEntry = hasOnEnterNotify
		region.notifyOnExit = hasOnExitNotify
	}
	
	/// Resume a paused request or start it
	public func resume() {
		Location.start(self)
	}
	
	/// Pause a running request.
	///
	/// - Returns: `true` if request is paused, `false` otherwise.
	public func pause() {
		Location.pause(self)
	}
	
	/// Cancel a running request and remove it from queue.
	public func cancel() {
		Location.cancel(self)
	}
	
	public func onResume() {
		
	}
	
	public func onCancel() {
		
	}
	
	public func onPause() {
		
	}
	
	public func dispatch(error: Error) {
		self.registeredCallbacks.forEach {
			if case .onError(let context, let handler) = $0 {
				context.queue.async { handler(error) }
			}
		}
		
		if self.cancelOnError == true { // remove from main location queue
			self.cancel()
			self._state = .failed
		}
	}
	
	
	/// Dispatch region state events to appropriate registered callbacks
	///
	/// - Parameter event: event received
	internal func dispatch(event: RegionEvent) {
		self.registeredCallbacks.forEach {
			switch ($0, event) {
			case (.onEnter(let context, let handler), .entered) :
				context.queue.async { handler() }
			case (.onExit(let context, let handler), .exited):
				context.queue.async { handler() }
			default:
				break
			}
		}
	}
	
	/// Dispatch region state events to appropriate registered callbacks
	///
	/// - Parameter state: state
	internal func dispatch(state: CLRegionState) {
		stateCallback?(state)
	}
	
}
