import 'package:flutter/material.dart';
import 'package:frontend/my_app.dart';
import 'environments/environment_singleton.dart';
import 'environments/local_config.dart';

void main() {
  Environment(baseConfig: LocalConfig());

  runApp(const MyApp());
}