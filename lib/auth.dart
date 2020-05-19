import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';


 class Key { 
 String idKey; 
 String token;
  
  Key({this.idKey, this.token});
 

 factory Key.fromJson(Map<String, dynamic> json) => Key(
        idKey: json["clientId"],token: json["clientSecret"]
      );
}


class GitHubLoginRequest {
  String clientId;
  String clientSecret;
  String code;

  GitHubLoginRequest({this.clientId, this.clientSecret, this.code});

  dynamic toJson() => {
        "client_id": clientId,
        "client_secret": clientSecret,
        "code": code,
      };
}

class GitHubLoginResponse {
  String accessToken;
  String tokenType;
  String scope;

  GitHubLoginResponse({this.accessToken, this.tokenType, this.scope});

  factory GitHubLoginResponse.fromJson(Map<String, dynamic> json) =>
      GitHubLoginResponse(
        accessToken: json["access_token"],
        tokenType: json["token_type"],
        scope: json["scope"],
      );
}

class GetGitData {
  String data;

  GetGitData({this.data});

  factory GetGitData.fromJson(Map<String, dynamic> json) => GetGitData(
        data: json["login"],
      );

}

class AuthService {



  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Firestore _db = Firestore.instance;

  Stream<FirebaseUser> user; 
  Stream<Map<String, dynamic>> profile; 
  PublishSubject loading = PublishSubject();

  AuthService() {
    user = _auth.onAuthStateChanged;

    profile = user.switchMap((FirebaseUser u) {
      if (u != null) {
        return _db
            .collection('users')
            .document(u.uid)
            .snapshots()
            .map((snap) => snap.data);
      } else {
        return Stream.value({});
      }
    });
  }


  Future<FirebaseUser> googleSignIn() async {
    loading.add(true);

    GoogleSignInAccount googleUser = await _googleSignIn.signIn();

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    FirebaseUser user = (await _auth.signInWithCredential(credential)).user;
    updateUserData(user, null);

    loading.add(false);
    return user;
  }


  Future<FirebaseUser> githubLogin() async {

    loading.add(true);

  String keyhjson = await rootBundle.loadString('assets/key.json');
  Key private = Key.fromJson(json.decode(keyhjson));

  print(private.idKey);

String idur = "https://github.com/login/oauth/authorize" +
        "?client_id=" + private.idKey +
        "&scope=public_repo%20read:user%20user:email";



  String url = idur;

    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
      );
    } else {
      print("CANNOT LAUNCH THIS URL!");
    }

    return null;
  }


  Future<FirebaseUser> firbaseFinish(String code) async {

  String keyhjson = await rootBundle.loadString('assets/key.json');
  Key private = Key.fromJson(json.decode(keyhjson));



     final response = await http.post(
      "https://github.com/login/oauth/access_token",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: jsonEncode(GitHubLoginRequest(
        clientId: private.idKey,
        clientSecret:private.token,
        code: code,
      )),
    );

    GitHubLoginResponse loginResponse =
        GitHubLoginResponse.fromJson(json.decode(response.body));

    final AuthCredential credential = GithubAuthProvider.getCredential(
      token: loginResponse.accessToken,
    );
    String accessToken = loginResponse.accessToken;
    

    FirebaseUser user = (await _auth.signInWithCredential(credential)).user;

    gitGet(accessToken, user);


    loading.add(false);
    return user; 

  }

  Future<String> gitGet(String token ,FirebaseUser user ) async {
    final response = await http.get(
      'https://api.github.com/user',

      headers: {HttpHeaders.authorizationHeader: "token" + " " + token},
    );

    GetGitData loginResponse = GetGitData.fromJson(json.decode(response.body));
   

    updateUserData(user,loginResponse.data);


    return loginResponse.data;

  }

  void updateUserData(FirebaseUser user,String username) async {

   
    DocumentReference ref = _db.collection('users').document(user.uid);


    return ref.setData({
      'uid': user.uid,
      'email': user.email,
      'photoURL': user.photoUrl,
      'displayName': user.providerId,
      'Name': user.displayName,
      'userName': username,
      'lastSeen': DateTime.now()
    }, merge: true);
  }

  void signOut() {
    _auth.signOut();
  }
}

final AuthService authService = AuthService();
