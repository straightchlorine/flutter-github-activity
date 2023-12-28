import 'package:flutter/material.dart';
import 'package:github_activity/github_activity.dart';
import 'package:github_activity/user_object.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:github_activity/github_service.dart';
import 'package:github_activity/state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(ActivityAdapter());
  runApp(GitHubActivity());
}

class GitHubActivity extends StatefulWidget {
  _GitHubActivityState createState() => _GitHubActivityState();
}

class _GitHubActivityState extends State<GitHubActivity> {

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      builder: (context, _) {
        final appState = Provider.of<AppState>(context);
        return MaterialApp(
          title: 'GitHub Activity',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            appBar: ApplicationControlBar(),
            body: ActivityScreen(),
            drawer: FetchedUsersDrawer(),
          )
        );
      },
    );
  }
}

class ApplicationControlBar extends StatefulWidget implements PreferredSizeWidget {
  @override
  _ApplicationControlBarState createState() => _ApplicationControlBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ApplicationControlBarState extends State<ApplicationControlBar> {

  var _prefs;

  _fetchPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    Provider.of<AppState>(context, listen: false).isDarkMode = prefs.getBool('isDarkMode') ?? false;
    Provider.of<AppState>(context, listen: false).loadFetched();
    Provider.of<AppState>(context, listen: false).loadCurrent();
    _prefs = prefs;
  }

  @override
  void initState() {
    super.initState();
    Provider.of<AppState>(context, listen: false).loadFetched();
    _fetchPrefs();
  }

  void toggleTheme() {
      Provider.of<AppState>(context, listen: false).toggleTheme(_prefs);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text('GitHub Activity'),
      actions: [
        IconButton(
          icon: Icon(Icons.brightness_4),
          onPressed: toggleTheme
        )
      ],
    );
  }
}

class ActivityScreen extends StatefulWidget {
  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {

  TextEditingController _usernameController = TextEditingController();
  final GitHubService _gitHubService = GitHubService();

  void _loadGitHubActivity() async {
    var appState = Provider.of<AppState>(context, listen: false);

    final username = _usernameController.text;
    if (username.isNotEmpty) {
      try {
        final user = await _gitHubService.getUser(username);
        final activities = await _gitHubService.getActivity(username);
        appState.current_user = user;
        appState.current_user!.activities = activities;
        appState.appendUser(appState.current_user);
      } catch (e) {
        print('Error: $e');
      }
    } else {
      print('Please enter a GitHub username');
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = Provider.of<AppState>(context, listen: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              if (appState.current_user != null)
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(appState.current_user?.avatar_url ?? 'url missing'),
                ),
                SizedBox(height: 10),
              if (appState.current_user != null)
                Text(
                  appState.current_user?.name ?? appState.current_user?.login ?? 'id missing',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'GitHub Username'),
              ),
              Padding(padding: EdgeInsets.only(top: 20),
                child: ElevatedButton(
                  onPressed: _loadGitHubActivity,
                  child: Text('Fetch GitHub Activity'),
                ),
              )
            ],
          ),
        ),
        Expanded(
          child: appState.current_user?.activities == null ? 
            Center(
              child: Text('No GitHub activity fetched to display')
            ) : ListView.builder(
            itemCount: appState.current_user?.activities.length,
            itemBuilder: (context, index) {
              final activity = appState.current_user!.activities[index];
              return ListTile(
                title: Text(activity.type),
                subtitle: Text('${activity.actorLogin} - ${activity.repoName}'),
                trailing: Text(activity.createdAt.toString()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FetchedUsersDrawer extends StatefulWidget {
  @override
  _FetchedUsersDrawerState createState() => _FetchedUsersDrawerState();
}

class _FetchedUsersDrawerState extends State<FetchedUsersDrawer> {

  @override
  Widget build(BuildContext context) {
    var appState = Provider.of<AppState>(context, listen: false);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
            ),
            child: Text(
              'Fetched Users',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          for (var item in appState.fetched.reversed.toList())
            ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(item?.avatar_url ?? 'none')),
              title: Text(item?.login ?? 'id missing'),
              subtitle: Text(item?.name ?? 'name missing'),
              onTap: () {
                appState.loadStoredActivity(item);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}
