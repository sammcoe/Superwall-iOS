//
//  File.swift
//
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation
import UIKit

class PaywallManager {
  @MainActor
  var presentedViewController: PaywallViewController? {
    return PaywallViewController.cache.first { $0.isActive }
	}
  private unowned let paywallRequestManager: PaywallRequestManager
  private unowned let factory: ViewControllerFactory & CacheFactory

  private lazy var cache: PaywallCache = factory.makeCache()

  init(
    factory: ViewControllerFactory & CacheFactory,
    paywallRequestManager: PaywallRequestManager
  ) {
    self.factory = factory
    self.paywallRequestManager = paywallRequestManager
  }

  @MainActor
	func removePaywallViewController(identifier: String?) {
    cache.removePaywallViewController(identifier: identifier)
	}

  @MainActor
	func removePaywallViewController(_ viewController: PaywallViewController) {
    cache.removePaywallViewController(viewController)
	}

  @MainActor
	func resetCache() {
		cache.clearCache()
	}

  /// First, this gets the paywall response for a specified paywall identifier or trigger event.
  /// It then creates the paywall view controller from that response, and caches it.
  ///
  /// If no `identifier` or `event` is specified, this gets the default paywall for the user.
  ///
  /// - Parameters:
  ///   - presentationInfo: Info concerning the cause of the paywall presentation and data associated with it.
  ///   - cached: Whether or not the paywall is cached.
  ///   - completion: A completion block called with the resulting paywall view controller.
  @MainActor
  func getPaywallViewController(
    from request: PaywallRequest
  ) async throws -> PaywallViewController {
    let paywall = try await paywallRequestManager.getPaywall(from: request)
    let notSubstitutingProducts = request.overrides.products == nil
    let debuggerNotLaunched = !request.dependencyContainer.debugManager.isDebuggerLaunched
    let shouldUseCache = notSubstitutingProducts && debuggerNotLaunched

    if shouldUseCache,
      let viewController = self.cache.getPaywallViewController(identifier: paywall.identifier) {
      // Set product-related vars again incase products have been substituted into paywall.
      viewController.paywall.products = paywall.products
      viewController.paywall.productIds = paywall.productIds
      viewController.paywall.swProducts = paywall.swProducts
      viewController.paywall.productVariables = paywall.productVariables
      viewController.paywall.swProductVariablesTemplate = paywall.swProductVariablesTemplate
      viewController.paywall.isFreeTrialAvailable = paywall.isFreeTrialAvailable
      viewController.paywall.productsLoadingInfo = paywall.productsLoadingInfo
      return viewController
    }

    let paywallViewController = factory.makePaywallViewController(for: paywall)

    if let window = UIApplication.shared.activeWindow {
      paywallViewController.view.alpha = 0.01
      window.addSubview(paywallViewController.view)
      paywallViewController.view.transform = CGAffineTransform(
        translationX: UIScreen.main.bounds.width,
        y: 0
      )
      .scaledBy(x: 0.1, y: 0.1)
    }

    return paywallViewController
	}
}
