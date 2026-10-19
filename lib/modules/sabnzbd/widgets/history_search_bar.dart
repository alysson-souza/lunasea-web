import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd.dart';

class SABnzbdHistorySearchBar extends StatefulWidget {
  final ScrollController scrollController;

  const SABnzbdHistorySearchBar({super.key, required this.scrollController});

  @override
  State<SABnzbdHistorySearchBar> createState() => _State();
}

class _State extends State<SABnzbdHistorySearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = context.read<SABnzbdState>().historySearchFilter;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Consumer<SABnzbdState>(
            builder: (context, state, _) => LunaTextInputBar(
              controller: _controller,
              scrollController: widget.scrollController,
              autofocus: false,
              labelText: 'Search loaded history',
              onChanged: (value) =>
                  context.read<SABnzbdState>().historySearchFilter = value,
              margin: EdgeInsets.zero,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Consumer<SABnzbdState>(
            builder: (context, state, _) => FilterChip(
              label: const Text('Failed only'),
              selected: state.historyHideFailed,
              onSelected: (value) => state.historyHideFailed = value,
            ),
          ),
        ),
      ],
    );
  }
}
