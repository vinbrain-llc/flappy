library flappy;

import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:feedback/feedback.dart';
import 'package:flappy/shake_listener.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';

class FlappyFeedback extends StatefulWidget {
  final Widget child;
  final String? appName;
  final List<String>? receiverEmails;
  final int maximumFileSize;

  FlappyFeedback({
    required this.child,
    this.appName,
    this.receiverEmails,
    this.maximumFileSize = 1000000,
  });

  @override
  _FlappyFeedbackState createState() => _FlappyFeedbackState();
}

class _FlappyFeedbackState extends State<FlappyFeedback> {
  @override
  void initState() {
    super.initState();
    _initLog();
  }

  @override
  Widget build(BuildContext context) {
    return BetterFeedback(
      child: ShakeListener(
        child: widget.child,
        listener: (context) => BetterFeedback.of(context)!
            .show((feedback, feedbackScreenshot) async {
          await _sendFeedback(feedback, feedbackScreenshot);
        }),
      ),
    );
  }

  Future<void> _sendFeedback(feedback, feedbackScreenshot) async {
    final date = DateFormat.yMMMd().add_Hms().format(DateTime.now());

    final directory = await getTemporaryDirectory();
    final imagePath = p.join(
      directory.path,
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(feedbackScreenshot);
    final attachmentPaths = [imageFile.path];
    attachmentPaths.addAll(await _getLogPaths());
    final email = Email(
      body: feedback,
      subject:
          '[Flappy Feedback] ${widget.appName != null ? '${widget.appName} ' : ''}$date',
      recipients: widget.receiverEmails ?? [],
      attachmentPaths: attachmentPaths,
    );
    ;
    await FlutterEmailSender.send(email);
  }

  void _initLog() {
    var fileName = DateTime.now().millisecondsSinceEpoch.toString();
    _prepareFiles();
    Logger.root.level = kDebugMode ? Level.ALL : Level.OFF;
    hierarchicalLoggingEnabled = true;
    Logger.root.onRecord.listen((record) async {
      final file = await _getLocalFile(fileName);
      if (await file.length() > widget.maximumFileSize) {
        fileName = DateTime.now().millisecondsSinceEpoch.toString();
      }
      await _logRecord(record, fileName);
      log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> _logRecord(LogRecord record, String name) async {
    final file = await _getLocalFile(name);
    final contents = '''
    Message: ${record.message}
    Time: ${record.time}
    Level: ${record.level.value}
    Name: ${record.loggerName}
    Error: ${record.error}
    StackTrace: ${record.stackTrace}

    ----------------------------------

    ''';
    await file.writeAsString(contents, mode: FileMode.append);
  }

  Future<File> _getLocalFile(String name) async {
    final path = await _localPath;
    final file = File('$path/logs/$name.csv');
    if (!await file.exists()) {
      await file.create();
    }
    return file;
  }

  void _prepareFiles() async {
    final path = await _localPath;
    final dir = Directory('$path/logs');
    var dirExist = await dir.exists();
    if (!dirExist) {
      await dir.create();
    }
    final files = await dir.list().toList();

    files.sort((a, b) => b.path.compareTo(a.path));
    //Remove old files
    while (files.length > 2) {
      await files.last.delete();
      files.removeLast();
    }
  }

  Future<List<String>> _getLogPaths() async {
    final path = await _localPath;
    final tempDir = await getTemporaryDirectory();

    final dir = Directory('$path/logs');
    var dirExist = await dir.exists();

    if (!dirExist) {
      await dir.create();
    }

    final files = await dir.list().toList();
    var paths = <String>[];
    //Copy csv files to cache folder, so we can send email with attachments
    for (var file in files) {
      final tempFile = File(file.path);
      final newPath = p.join(tempDir.path, p.basename(file.path));
      await tempFile.copy(newPath);
      paths.add(newPath);
    }
    return paths;
  }
}
