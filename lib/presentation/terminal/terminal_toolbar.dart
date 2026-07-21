import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// A compact row of hard-to-type keys for the terminal (essential on mobile,
/// handy on desktop). Feeds directly into the [Terminal] via [Terminal.keyInput].
class TerminalToolbar extends StatelessWidget {
  const TerminalToolbar({required this.terminal, super.key});

  final Terminal terminal;

  void _key(TerminalKey key, {bool ctrl = false}) =>
      terminal.keyInput(key, ctrl: ctrl);

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      _btn('Esc', () => _key(TerminalKey.escape)),
      _btn('Tab', () => _key(TerminalKey.tab)),
      _btn('^C', () => _key(TerminalKey.keyC, ctrl: true)),
      _btn('^D', () => _key(TerminalKey.keyD, ctrl: true)),
      _btn('^L', () => _key(TerminalKey.keyL, ctrl: true)),
      _iconBtn(Icons.keyboard_arrow_up, () => _key(TerminalKey.arrowUp)),
      _iconBtn(Icons.keyboard_arrow_down, () => _key(TerminalKey.arrowDown)),
      _iconBtn(Icons.keyboard_arrow_left, () => _key(TerminalKey.arrowLeft)),
      _iconBtn(Icons.keyboard_arrow_right, () => _key(TerminalKey.arrowRight)),
    ];

    return Material(
      elevation: 2,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: buttons.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, i) => buttons[i],
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => _Chip(onTap: onTap, child: Text(label));

  Widget _iconBtn(IconData icon, VoidCallback onTap) =>
      _Chip(onTap: onTap, child: Icon(icon, size: 18));
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(40, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
      ),
      child: child,
    );
  }
}
