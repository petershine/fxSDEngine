

import UIKit


extension UIView {

	@objc public class func view(fromNibName nibName: String? = nil, owner: Any? = nil) -> UIView? {	fxd_log()

		let resourceBundle = Bundle.init(for: self.classForCoder())

		let nib = UINib.init(nibName: nibName ?? String(describing: self), bundle: resourceBundle)

		let views = nib.instantiate(withOwner: owner, options: nil) as? [UIView]

		fxdPrint("nibName: \(String(describing: nibName ?? String(describing: self)))")
		fxdPrint("resourceBundle: \(String(describing: resourceBundle))")
		fxdPrint("nib: \(String(describing: nib))")
		fxdPrint("views: \(String(describing: views))")

		return views?.first
	}
}


extension UIView {
	@objc public func fadeInFromHidden() {
		guard (self.isHidden || self.alpha != 1.0) else {
			return
		}

		self.alpha = 0.0;
		self.isHidden = false;

		UIView.animate(withDuration: DURATION_ANIMATION) {
			self.alpha = 1.0
		}
	}

	@objc public func fadeOutThenHidden() {
		guard (self.isHidden == false) else {
			return
		}

		let previousAlpha = self.alpha

		UIView.animate(withDuration: DURATION_ANIMATION,
		               animations: {
						self.alpha = 0.0
		}) { (didFinish: Bool) in
			self.isHidden = true
			self.alpha = previousAlpha
		}
	}

	@objc public func addAsFadeInSubview(_ subview: UIView?, afterAddedBlock: (() -> Swift.Void)? = nil) {

		guard subview != nil else {
			afterAddedBlock?()
			return
		}

		subview?.alpha = 0.0

		self.addSubview(subview!)
		self.bringSubviewToFront(subview!)

		UIView.animate(
			withDuration: DURATION_ANIMATION,
			animations: {
				subview?.alpha = 0.0

		}) { (didFinish: Bool) in
			afterAddedBlock?()
		}
	}

	@objc public func removeAsFadeOutSubview(_ subview: UIView?, afterRemovedBlock: (() -> Swift.Void)? = nil) {

		guard subview != nil else {
			afterRemovedBlock?()
			return
		}

		UIView.animate(
			withDuration: DURATION_ANIMATION,
			animations: {
			subview?.alpha = 0.0

		}) { (didFinish: Bool) in
			subview?.removeFromSuperview()
			subview?.alpha = 1.0

			afterRemovedBlock?()
		}
	}

	@objc public func modifyToCircular() {
		self.layer.masksToBounds = true
		self.layer.cornerRadius = self.bounds.size.width/2.0
	}

	@objc public func removeAllSubviews() {
		for subview in self.subviews {
			subview.removeFromSuperview()
		}
	}
}

extension UIView {
	@objc public func superView(forClassName className: String) -> UIView? {

        guard superview != nil else {
            return nil
        }

		var foundView: UIView? = nil

        if String(describing: superview!.classForCoder.self) == className {
            foundView = superview
        }
        else {
            // Recursive call
            foundView = superview?.superView(forClassName: className)
        }

		return foundView
	}
}

extension UIView {
	@objc public func blinkShadowOpacity() {
		let blinkShadow: CABasicAnimation = CABasicAnimation.init(keyPath: "shadowOpacity")
		blinkShadow.fromValue = self.layer.shadowOpacity
		blinkShadow.toValue = 0.0
		blinkShadow.duration = DURATION_ANIMATION
		blinkShadow.autoreverses = true
		self.layer.add(blinkShadow, forKey: "shadowOpacity")
	}
}

