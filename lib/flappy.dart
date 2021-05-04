library flappy;

import 'dart:developer';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';

import 'package:feedback/feedback.dart';
import 'package:flappy/shake_listener.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';

const _1MB = 1000000;

class FlappyFeedback extends StatefulWidget {
  final Widget child;
  final String? appName;
  final List<String>? receiverEmails;
  final int maximumFileSize;
  final bool consoleLog;

  FlappyFeedback({
    required this.child,
    this.appName,
    this.receiverEmails,
    this.maximumFileSize = _1MB,
    this.consoleLog = false,
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

  void _initLog() async {
    _prepareFiles();
    var fileName = await _getLatestFile();
    hierarchicalLoggingEnabled = true;

    Logger.root.level = widget.consoleLog ? Level.ALL : Level.OFF;

    Logger.root.onRecord.listen((record) async {
      final file = await _getLocalFile(fileName);

      if (await file.length() > widget.maximumFileSize) {
        fileName = await _getLatestFile(newFile: true);
        _prepareFiles();
      }
      await _logRecord(record, fileName);
      if (widget.consoleLog) {
        log(
          record.message,
          time: record.time,
          level: record.level.value,
          name: record.loggerName,
          error: record.error,
          stackTrace: record.stackTrace,
        );
      }
    });
  }

  Future<String> _getLatestFile({bool newFile = false}) async {
    final localPath = await _localPath;
    final dir = Directory('$localPath/logs');
    var dirExist = await dir.exists();
    if (!dirExist) {
      await dir.create();
    }
    final files = await dir.list().toList();
    var name = '';

    if (files.isNotEmpty && !newFile) {
      files.sort((a, b) => b.path.compareTo(a.path));
      name = p.basename(files.first.path);
    } else {
      final newFileName =
          '${DateTime.now().millisecondsSinceEpoch.toString()}.csv';
      name = newFileName;
      _setupFirstRow(newFileName);
    }

    return name;
  }

  void _setupFirstRow(String fileName) async {
    final file = await _getLocalFile(fileName);
    String csvData = ListToCsvConverter().convert([
      ['Message', 'Time', 'Level', 'Name', 'Error', 'StackTrace']
    ]);
    await file.writeAsString('$csvData\n', mode: FileMode.append);
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> _logRecord(LogRecord record, String name) async {
    final file = await _getLocalFile(name);
    String csvData = ListToCsvConverter().convert([
      [
        record.message,
        record.time,
        record.level.name,
        record.loggerName,
        record.error,
        record.stackTrace
      ]
    ]);
    await file.writeAsString('$csvData\n', mode: FileMode.append);
  }

  Future<File> _getLocalFile(String name) async {
    final path = await _localPath;
    final file = File('$path/logs/$name');
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
    while (files.length > 3) {
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
