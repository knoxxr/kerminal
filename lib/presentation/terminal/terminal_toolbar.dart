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
    // `^C` style labels only mean something to people who already know them, so
    // each key spells out what it does in its tooltip. The labels stay short —
    // the row has to fit a phone — but read as keys, not as symbols.
    final buttons = <Widget>[
      _btn('Esc', 'Escape', () => _key(TerminalKey.escape)),
      _btn('Tab', 'Tab — complete or indent', () => _key(TerminalKey.tab)),
      _btn('Ctrl+C', 'Stop the running command',
          () => _key(TerminalKey.keyC, ctrl: true)),
      _btn('Ctrl+D', 'End of input — log out of the shell',
          () => _key(TerminalKey.keyD, ctrl: true)),
      _btn('Ctrl+L', 'Clear the screen',
          () => _key(TerminalKey.keyL, ctrl: true)),
      _iconBtn(Icons.keyboard_arrow_up, 'Up — previous command',
          () => _key(TerminalKey.arrowUp)),
      _iconBtn(Icons.keyboard_arrow_down, 'Down — next command',
          () => _key(TerminalKey.arrowDown)),
      _iconBtn(Icons.keyboard_arrow_left, 'Left',
          () => _key(TerminalKey.arrowLeft)),
      _iconBtn(Icons.keyboard_arrow_right, 'Right',
          () => _key(TerminalKey.arrowRight)),
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

  Widget _btn(String label, String tooltip, VoidCallback onTap) =>
      _Chip(onTap: onTap, tooltip: tooltip, child: Text(label));

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) =>
      _Chip(onTap: onTap, tooltip: tooltip, child: Icon(icon, size: 18));
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child, required this.onTap, required this.tooltip});

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      // Touch users never hover, so make a long-press reveal it too.
      triggerMode: TooltipTriggerMode.longPress,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        child: child,
      ),
    );
  }
}
