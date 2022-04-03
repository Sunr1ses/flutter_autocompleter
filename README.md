# Flutter Autocompleter

A customizable autocomplete widget for text field for Flutter

## Features
* Supports TextField, CupertinoTextField, TextFormField and even your own custom text field widget
* Customizes list item, padding, margin and decoration
* Customizes content for loading, empty and error state
* Installs hook before and after the suggestion callback
* Sets debounce duration when listening text changes
* Auto-flip when the list is outside the viewport

## Example
```dart
Autocompleter<String>(
  debounce: 300,
  flip: true,
  controller: _textEditingController,
  callback: (q) async {
    var data = ['apple', 'banana', 'cat', 'dog', 'app', '1234'];
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
  loadingBuilder: (_) => const Center(
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
  onTap: (s) {
    setState(() {
      _textEditingController.text = s;
      _textEditingController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textEditingController.text.length));
    });
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
              body: Center(child: Text(s)),
            )));
  },
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
  child: TextField(
    controller: _textEditingController,
  ),
  direction: VerticalDirection.down)
```