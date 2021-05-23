import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/sendgrid.dart';

void main(List<String> arguments) {
  Map<String, String> env = Platform.environment;
  final username = env['SENDGRID_USERNAME'] ?? '';
  final password = env['SENDGRID_PASSWORD'] ?? '';

  final projectId = env['APPWRITE_FUNCTION_PROJECT_ID'] ?? '';
  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'http://localhost/v1';
  final key = env['APPWRITE_KEY'] ?? '';
  final collectionId = env['COLLECTION_ID'] ?? '';

  Client client = Client(endPoint: endpoint).setProject(projectId).setKey(key);

  final users = Users(client);
  users.list().then((res) async {
    final userList = res.data['users'];
    for (var user in userList) {
      final String? email = user['email'];
      if (email != null && !email.isEmpty) {
        print('sending email to ${email}');
        final sendmail = !(await hasIntakes(
            client: client, collectionId: collectionId, userId: user['\$id']));
        if (sendmail) {
          await sendMail(username, password, email);
        }
      }
    }
  }).catchError((error) {
    if (error is AppwriteException) {
      print(error.message);
    } else {
      print(error);
    }
  });
}

Future sendMail(String username, String password, String email) async {
  final smtpServer = sendgrid(username, password);

  final message = Message()
    ..from = Address('damodar@appwrite.io', 'Damodar')
    ..recipients.add(email)
    ..subject = 'Simple reminder to drink water'
    ..text =
        'Hey, how are you doing? \nThis is just a simple reminder to drink water. \nStay Hydrated and Stay Healthy.';
  try {
    final sendReport = await send(message, smtpServer);
    print('Message sent: ${sendReport.toString()}');
  } on MailerException catch (e) {
    print('message not sent');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
  }
}

Future<bool> hasIntakes(
    {required Client client,
    required String collectionId,
    required String userId,
    DateTime? date}) async {
  final Database _db = Database(client);
  date = date ?? DateTime.now();
  final from = DateTime(date.year, date.month, date.day, 0);
  final to = DateTime(date.year, date.month, date.day, 23, 59, 59);
  try {
    final res = await _db.listDocuments(
        collectionId: collectionId,
        filters: [
          'user_id=${userId}'
              'date>=${from.millisecondsSinceEpoch}',
          'date<=${to.millisecondsSinceEpoch}'
        ],
        orderField: 'date',
        orderType: OrderType.desc);
    if (res.data['sum'] > 0) {
      return true;
    } else {
      return false;
    }
  } on AppwriteException catch (e) {
    print(e.message);
    return false;
  }
}
