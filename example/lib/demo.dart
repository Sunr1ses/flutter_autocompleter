import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_autocompleter/flutter_autocompleter.dart';

class Demo extends StatefulWidget {
  const Demo({Key? key}) : super(key: key);

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  final TextEditingController _textEditingController =
      TextEditingController(text: '');

  final TextEditingController _cupertinoTextEditingController =
      TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _cupertinoTextEditingController.dispose();
    super.dispose();
  }

  bool flip = false;
  VerticalDirection direction = VerticalDirection.down;
  int debounce = 0;
  Widget Function(BuildContext)? loadingBuilder;
  Widget Function(BuildContext)? emptyBuilder;
  bool Function(String)? beforeHook;

  Widget _autocompleter(BuildContext context, Widget child,
      TextEditingController textEditingController) {
    return Autocompleter<String>(
        debounce: debounce,
        flip: flip,
        controller: textEditingController,
        callback: (q) async {
          var data = ['apple', 'banana', 'cat', 'dog', 'app', '1234'];
          await Future.delayed(const Duration(seconds: 1));
          return Future.value(
              data.where((element) => element.contains(q)).toList());
        },
        errorBuilder: (_) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Error occured'),
          );
        },
        itemBuilder: (_, s) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(s),
          );
        },
        loadingBuilder: loadingBuilder,
        emptyBuilder: emptyBuilder,
        onTap: (s) {
          setState(() {
            textEditingController.text = s;
            textEditingController.selection = TextSelection.fromPosition(
                TextPosition(offset: textEditingController.text.length));
          });
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                    body: Center(child: Text(s)),
                  )));
        },
        beforeHook: beforeHook,
        decorationBuilder: (direction) => BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: direction == VerticalDirection.up
                      ? const Radius.circular(16.0)
                      : Radius.zero,
                  bottom: direction == VerticalDirection.down
                      ? const Radius.circular(16.0)
                      : Radius.zero,
                ),
                boxShadow: const [
                  BoxShadow(blurRadius: 3.0, color: Colors.black12)
                ]),
        child: child,
        direction: direction);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          options(context),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _autocompleter(
                    context,
                    TextField(
                      controller: _textEditingController,
                    ),
                    _textEditingController),
                const SizedBox(
                  height: 16,
                ),
                _autocompleter(
                    context,
                    CupertinoTextField(
                      controller: _cupertinoTextEditingController,
                    ),
                    _cupertinoTextEditingController)
              ])),
        ],
      ),
    );
  }

  List<bool Function(String)?> beforeHookOptions = [
    null,
    (s) => s.length > 1,
    (s) {
      return num.tryParse(s) != null;
    }
  ];
  Widget options(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Direction'),
              const SizedBox(
                width: 16,
              ),
              ToggleButtons(
                children: const [
                  Text('Down'),
                  Text('Up'),
                ],
                onPressed: (int index) {
                  setState(() {
                    direction = index == 0
                        ? VerticalDirection.down
                        : VerticalDirection.up;
                  });
                },
                isSelected: [
                  direction == VerticalDirection.down,
                  direction == VerticalDirection.up
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Flip'),
              const SizedBox(
                width: 16,
              ),
              ToggleButtons(
                children: const [
                  Text('True'),
                  Text('False'),
                ],
                onPressed: (int index) {
                  setState(() {
                    flip = index == 0;
                  });
                },
                isSelected: [flip, !flip],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Debounce'),
              const SizedBox(
                width: 16,
              ),
              ToggleButtons(
                children: const [
                  Text('0'),
                  Text('1000'),
                  Text('2000'),
                ],
                onPressed: (int index) {
                  setState(() {
                    debounce = [0, 1000, 2000][index];
                  });
                },
                isSelected: [0 == debounce, 1000 == debounce, 2000 == debounce],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Loading builder'),
              const SizedBox(
                width: 16,
              ),
              ToggleButtons(
                children: const [
                  Text('No'),
                  Text('Circular Progress Indicator'),
                ],
                onPressed: (int index) {
                  setState(() {
                    loadingBuilder = [
                      null,
                      (context) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  )),
                            ),
                          ),
                    ][index];
                  });
                },
                isSelected: [loadingBuilder == null, loadingBuilder != null],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Empty builder'),
              const SizedBox(
                width: 16,
              ),
              ToggleButtons(
                children: const [
                  Text('No'),
                  Text('Text'),
                ],
                onPressed: (int index) {
                  setState(() {
                    emptyBuilder = [
                      null,
                      (context) => const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No results'))),
                    ][index];
                  });
                },
                isSelected: [emptyBuilder == null, emptyBuilder != null],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Before hook'),
              const SizedBox(
                width: 16,
              ),
              ToggleButtons(
                children: const [
                  Text('No'),
                  Text('Length > 1'),
                  Text('Number only'),
                ],
                onPressed: (int index) {
                  setState(() {
                    beforeHook = beforeHookOptions[index];
                  });
                },
                isSelected: List.generate(
                    3, (index) => beforeHookOptions[index] == beforeHook),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
