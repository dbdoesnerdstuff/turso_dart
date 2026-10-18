import 'dart:io';

import 'package:turso_dart/turso_dart.dart';

Future<void> main() async {
  final path = Platform.environment['TURSO_PROBE_DB_PATH']!;
  final remoteUrl = Platform.environment['REPLICA_SYNC_URL']!;
  final mode = Platform.environment['TURSO_PROBE_MODE'] ?? 'write';
  final expectedBody = Platform.environment['TURSO_PROBE_BODY'];
  final clientName = Platform.environment['TURSO_PROBE_CLIENT'] ?? path;
  final logicalMvccPull = Platform.environment['TURSO_LOGICAL_MVCC_PULL'];
  final bootstrapIfEmpty =
      Platform.environment['TURSO_BOOTSTRAP_IF_EMPTY'] == 'true';
  final database = connectSync(
    SyncDbConfig(
      path,
      remoteUrl: remoteUrl,
      clientName: 'turso-dart-fork-$clientName',
      bootstrapIfEmpty: bootstrapIfEmpty,
      logicalMvccPull: logicalMvccPull == null
          ? null
          : logicalMvccPull == 'true',
    ),
  );
  final connection = database.connect();
  connection.execute('''
    CREATE TABLE IF NOT EXISTS notes (
      id TEXT PRIMARY KEY,
      body TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  final body = expectedBody ?? 'fork-${DateTime.now().microsecondsSinceEpoch}';
  if (mode == 'write') {
    connection.execute(
      'INSERT INTO notes (id, body, created_at) VALUES (?1, ?2, ?3)',
      params: Params.positional([
        body,
        body,
        DateTime.now().toUtc().toIso8601String(),
      ]),
    );
  }
  if (mode == 'write') database.push();
  final changed = database.pull();
  final freshConnection = database.connect();
  final rows = freshConnection.query(
    'SELECT body FROM notes WHERE body = ?1',
    params: Params.positional([body]),
  );
  stdout.writeln('FORK_BODY=$body');
  stdout.writeln('FORK_PULL_CHANGED=$changed');
  stdout.writeln('FORK_LOCAL_ROWS=${rows.length}');
}
