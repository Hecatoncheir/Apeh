import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class WindowsUpdateButton extends StatelessWidget {
  const WindowsUpdateButton({super.key, required http.Client client});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
