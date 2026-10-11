import 'package:integration_test/integration_test.dart';

import '../test/flows/flow_1_deep_link_join_test.dart' as flow;

/// On-device run of the V-4b widget flow (see APP_GUIDE "Verifying").
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  flow.main();
}
