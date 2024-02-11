import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:mindfulguard/crypto/crypto.dart';
import 'package:mindfulguard/db/database.dart';
import 'package:mindfulguard/net/api/auth/sign_in.dart';
import 'package:mindfulguard/net/api/configuration.dart';
import 'package:mindfulguard/view/components/buttons.dart';
import 'package:mindfulguard/view/components/text_filelds.dart';
import 'package:mindfulguard/view/main/main_page.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SignInPage extends StatefulWidget {
  SignInPage({Key? key}) : super(key: key);

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String errorMessage = "";

  TextEditingController apiUrl = TextEditingController();
  TextEditingController login = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController privateKey = TextEditingController();
  DateTime selectedDateTime = DateTime.now();
  TextEditingController oneTimeOrBackupCode = TextEditingController();
  String? _selectedOption = "";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppLocalizations.of(context)!.signIn,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AlignTextField(
                  labelText: "Api url",
                  controller: apiUrl,
                ),
                SizedBox(height: 10),
                AlignTextField(
                  labelText: "Login",
                  controller: login,
                ),
                SizedBox(height: 10),
                AlignTextField(
                  labelText: "Password",
                  obscureText: true,
                  keyboardType: TextInputType.visiblePassword,
                  controller: password,
                ),
                SizedBox(height: 10),
                AlignTextField(
                  obscureText: true,
                  keyboardType: TextInputType.visiblePassword,
                  labelText: "Private key",
                  controller: privateKey,
                ),
                SizedBox(height: 10),
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)!.tokenExpirationDays(90),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${selectedDateTime.year}-${selectedDateTime.month}-${selectedDateTime.day} ${selectedDateTime.hour}:${selectedDateTime.minute}",
                  ),
                  onTap: () {
                    _selectDateTime(context);
                  },
                ),
                Divider(),
                SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AlignTextField(
                        labelText: "Totp",
                        controller: oneTimeOrBackupCode,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 10), // Add a small space between elements
                    DropDown(
                      options: const ['basic', 'backup'],
                      onOptionChanged: (String? selectedValue) {
                        _selectedOption = selectedValue;
                        print(selectedValue);
                        // Perform other actions upon value change
                      },
                    ),
                  ],
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
                    foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                  ),
                  onPressed: () async {
                    final signInApi = await _signInApi();
                    if (signInApi == null || signInApi?.statusCode != 200) {
                      setState(() {
                        errorMessage = json.decode(utf8.decode(signInApi!.body.runes.toList()))['msg'][AppLocalizations.of(context)?.localeName] ?? json.decode(signInApi!.body)['msg']['en'];

                      });
                    } else {
                      setState(() {
                        errorMessage = json.decode(utf8.decode(signInApi.body.runes.toList()))['msg'][AppLocalizations.of(context)?.localeName] ?? json.decode(signInApi!.body)['msg']['en'];
                      });
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => MainPage()),
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.next),
                ),
                // Add a container to display the error message
                Container(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: errorMessage != null ? Text(errorMessage, style: TextStyle(color: Colors.red)) : SizedBox() 
                  ),
                ),
                SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 90)), // Max 90 days
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<Response?> _signInApi() async {
    var configApi = await ConfigurationApi(apiUrl.text).execute();
    if (configApi!.statusCode != 200){
      return null;
    }
    Map<String, dynamic> configResponse = json.decode(configApi!.body);
    print(configApi.body);
    print(configApi.statusCode);

    RegExp regExp = RegExp(configResponse['password_rule']);
    if (!regExp.hasMatch(password.text)){
      return null;
    }

    String secretString = Crypto.hash().sha(utf8.encode(login.text+password.text+privateKey.text)).toString();
    var signInApi = await SignInApi(
      apiUrl.text,
      login.text,
      secretString,
      (selectedDateTime.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch) ~/ 60000, // From unixtime (milliseconds) to minutes.
      oneTimeOrBackupCode.text,
      _selectedOption!
    ).execute();

    if (signInApi!.statusCode != 200){
      return signInApi;
    }

    String token = json.decode(signInApi.body)['token'];

    final modelUser = ModelUserCompanion(
      login: drift.Value(login.text),
      password: drift.Value(password.text),
      privateKey: drift.Value(privateKey.text),
      accessToken: drift.Value(token)
    );

    final modelSettings = ModelSettingsCompanion(
      key: drift.Value('api_url'),
      value: drift.Value(apiUrl.text)
    );

    final db = AppDb();
    await db.into(db.modelUser)
      .insert(
        modelUser,
        onConflict: drift.DoUpdate((_)=>modelUser, target: [db.modelUser.login]), 
      );
    await db.into(db.modelSettings)
      .insert(
        modelSettings,
        onConflict: drift.DoUpdate((_)=>modelSettings, target: [db.modelSettings.key]), 
      );
    return signInApi;
  }
}