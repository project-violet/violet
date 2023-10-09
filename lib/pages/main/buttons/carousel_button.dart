import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CarouselButton extends StatelessWidget {
  const CarouselButton({
    super.key,
    required this.uri,
    required this.backgroundColor,
    required this.icon,
    required this.label,
  });

  final Uri? uri;
  final Color backgroundColor;
  final Widget icon;
  final Widget label;

  Future<void> _handleTapAsync() async {
    final uri = this.uri;

    if (uri == null) {
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handleTap() {
    _handleTapAsync();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: backgroundColor,
      child: InkWell(
        onTap: _handleTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: Theme.of(context).iconTheme.copyWith(color: Colors.white),
                child: icon,
              ),
              const SizedBox(width: 8.0),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontFamily: 'Calibre-Semibold',
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                  child: label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
