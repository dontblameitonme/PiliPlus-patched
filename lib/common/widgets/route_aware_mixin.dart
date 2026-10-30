import 'package:flutter/widgets.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/routes/default_route.dart'
    show GetPageRoute;

final routeObserver = RouteObserver<GetPageRoute>();

mixin RouteAwareMixin<T extends StatefulWidget> on State<T>, RouteAware {
  GetPageRoute? _subscribedRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // BUG-16: subscribe to the route that actually hosts this widget instead
    // of `Get.routing.route`, which may point to another route (dialog, etc.).
    final route = ModalRoute.of(context) ?? Get.routing.route;
    if (route is GetPageRoute && !identical(route, _subscribedRoute)) {
      if (_subscribedRoute != null) {
        routeObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _subscribedRoute = null;
    super.dispose();
  }
}
