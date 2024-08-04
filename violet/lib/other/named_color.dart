import 'package:flutter/material.dart';

Map<int, String> colorValueToNameMap = {
  Colors.red.value: 'red',
  Colors.pink.value: 'pink',
  Colors.purple.value: 'purple',
  Colors.deepPurple.value: 'deepPurple',
  Colors.indigo.value: 'indigo',
  Colors.blue.value: 'blue',
  Colors.lightBlue.value: 'lightBlue',
  Colors.cyan.value: 'cyan',
  Colors.teal.value: 'teal',
  Colors.green.value: 'green',
  Colors.lightGreen.value: 'lightGreen',
  Colors.lime.value: 'lime',
  Colors.yellow.value: 'yellow',
  Colors.amber.value: 'amber',
  Colors.orange.value: 'orange',
  Colors.deepOrange.value: 'deepOrange',
  Colors.brown.value: 'brown',
  Colors.grey.value: 'grey',
  Colors.blueGrey.value: 'blueGrey',
  Colors.black.value: 'black',
};

extension NamedColor on Color {
  String get name => colorValueToNameMap[value]!;
}
