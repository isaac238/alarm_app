// Dart imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import "dart:math";

// Packages
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:alarm/alarm.dart';

void main() async {
	WidgetsFlutterBinding.ensureInitialized();
	await Alarm.init();
	runApp(const MyApp());
}


class AlarmObject {
	int? id;
	String time;
	bool enabled;

	AlarmObject({required this.time, required this.enabled});

	Map<String, dynamic> toJson() {
		return {
			'time': time,
			'enabled': enabled,
			'id': id,
		};
	}

	AlarmObject.fromJson(Map<String, dynamic> json):
	time = json['time'] as String,
	enabled = json['enabled'] as bool,
	id = json['id'] as int;


	DateTime getDateTime() {
		DateTime now = DateTime.now();
		DateTime alarmDT = DateTime(
			now.year,
			now.month,
			now.day,
			int.parse(time.split(":")[0]),
			int.parse(time.split(":")[1])
		);

		if (now.isAfter(alarmDT)) {
			alarmDT = DateTime(alarmDT.year, alarmDT.month, alarmDT.day + 1, alarmDT.hour, alarmDT.minute);
		}

		return alarmDT;
	}
	static Future<AlarmObject> create(String time, bool enabled) async {
		AlarmObject alarm = AlarmObject(time: time, enabled: enabled);
		List<AlarmObject> currentAlarms = await readAlarms();
		Random random = Random();
		int id = int.parse(random.nextInt(100).toString() + time.replaceAll(RegExp(r"\D"), ""));

		while (currentAlarms.any((alarm) => alarm.id == id)) {
			id = int.parse(random.nextInt(100).toString() + time.replaceAll(RegExp(r"\D"), ""));
		}

		alarm.id = id;
		print("ID: ${id.toString()}");
		print("New Alarm: ${alarm.toJson().toString()}");
		await writeAlarm(alarm);
		return alarm;
	}
}

Future<File> getStorageFile() async {
	final documentDirectory = await getExternalStorageDirectory();
	final path = documentDirectory?.path;
	print(path);
	final file = File('$path/alarms.json');
	return file;
}

Future<File> writeAlarm(AlarmObject alarm) async {
	final file = await getStorageFile();

	List<AlarmObject> alarms = await readAlarms();
	alarms.add(alarm);

	JsonEncoder encoder = const JsonEncoder.withIndent("	");
	String json = encoder.convert(alarms);

	print("Writing alarm: ${encoder.convert(alarm)}");
	return file.writeAsString(json);
}

Future<File> deleteAlarm(AlarmObject alarm) async {
	final file = await getStorageFile();

	List<AlarmObject> alarms = await readAlarms();
	alarms.remove(alarms.where((iterAlarm) => iterAlarm.id == alarm.id).first);
	Alarm.stop(alarm.id!);

	JsonEncoder encoder = const JsonEncoder.withIndent("	");
	String json = encoder.convert(alarms);

	return file.writeAsString(json);
}

Future<bool> toggleAlarm(AlarmObject alarm) async {
	final file = await getStorageFile();

	List<AlarmObject> alarms = await readAlarms();
	alarms[alarms.indexOf(alarms.where((iterAlarm) => iterAlarm.id == alarm.id).first)].enabled = alarm.enabled;

	JsonEncoder encoder = const JsonEncoder.withIndent("	");
	String json = encoder.convert(alarms);

	await file.writeAsString(json);
	await readAlarms();
	return alarm.enabled;
}

Future<File> clearAlarms() async {
	final file = await getStorageFile();
	await Alarm.stopAll();
	return file.writeAsString("");
}


Future<List<AlarmObject>> readAlarms() async {
	try {
		final file = await getStorageFile();
		print("Reading JSON:");
		List<AlarmObject> alarms = [];
		if (await file.length() > 0) {
			String contents = await file.readAsString();
			print(contents);
			Iterable alarmsJSON = jsonDecode(contents);
			print(alarmsJSON);
			alarms = alarmsJSON.map((model) => AlarmObject.fromJson(model)).toList();
		}

		await Alarm.stopAll();
		for (AlarmObject alarm in alarms.where((alarm) => alarm.enabled)) {
			AlarmSettings alarmSettings = AlarmSettings(
				id: alarm.id!,
				dateTime: alarm.getDateTime(),
				assetAudioPath: "assets/imperial_alarm.mp3",
				loopAudio: true,
				vibrate: true,
				volumeMax: true,
				fadeDuration: 3.0,
				notificationTitle: "Alarm",
				notificationBody: "It's ${alarm.time}!",
				enableNotificationOnKill: true,
			);

			await Alarm.set(alarmSettings: alarmSettings);
		}
		print("Alarms: ");
		Alarm.getAlarms().forEach((alarm) => print(alarm.id));

		return alarms;
	} catch (e) {
		return [];
	}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Alarm App",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}



class AlarmDisplay extends StatefulWidget {
	const AlarmDisplay({super.key, required this.alarm});

	final AlarmObject alarm;

	@override
	State<AlarmDisplay> createState() => _AlarmDisplayState();
}

class _AlarmDisplayState extends State<AlarmDisplay> {
	void _toggleAlarm(bool value) async {
		setState(() {
			widget.alarm.enabled = value;
		});
		await toggleAlarm(widget.alarm);
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			margin: const EdgeInsets.all(15),
			padding: const EdgeInsets.all(10),
			decoration: BoxDecoration(
				borderRadius: BorderRadius.circular(10),
				color: Colors.white,
			),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceBetween,
				children: <Widget>[
					Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: <Widget>[
							const Text(
								'Alarm At',
								style: TextStyle(
									fontSize: 16,
									color: Colors.black,
								),
							),
							Text(
								widget.alarm.time,
								style: const TextStyle(
									fontSize: 32,
									color: Colors.black,
								),
							),
						],
					),
					Switch(
						value: widget.alarm.enabled,
						activeColor: Colors.green,
						inactiveThumbColor: Colors.grey,
						onChanged: (bool value) async {
							_toggleAlarm(value);
						},
					)
				]
			),
		);
	}
}


String getDateHoursMins(dynamic date) {
	if (!(date is DateTime || date is TimeOfDay)) {
		return "";
	}

	String mins = date.minute.toString();
	String hours = date.hour.toString();

	if (mins.length == 1) {
		mins = "0$mins";
	}

	if (hours.length == 1) {
		hours = "0$hours";
	}

	return "$hours:$mins";
}

class _MyHomePageState extends State<MyHomePage> {
	Future<List<AlarmObject>>? alarms;
	AlarmObject? ringing;

	void _displayNewAlarmTimePicker() async {
		TimeOfDay? value = await showTimePicker(
			context: context,
			initialTime: TimeOfDay.now(),
		);

		if (value == null) {
			return;
		}

		setState(() async {
			String newAlarmTime = getDateHoursMins(value);
			await AlarmObject.create(newAlarmTime, true);
			alarms = readAlarms();
		});
	}

  @override
  void initState() {
	alarms = readAlarms();
	super.initState();
  }
  @override
  Widget build(BuildContext context) {
	DateTime now = DateTime.now();
	String currentTime = getDateHoursMins(now);
	Duration duration = const Duration(seconds: 1);

	Timer.periodic(duration, (Timer timer ) => setState(() {
		now = DateTime.now();
		currentTime = getDateHoursMins(now);
	}));

    return Scaffold(
		body: Container(
			padding: const EdgeInsets.only(top: 50),
			width: double.infinity,
			height: double.infinity,
			decoration: BoxDecoration(
				gradient: LinearGradient(
					begin: Alignment.topCenter,
					end: const Alignment(0.0, 0.00001),
					colors: [
						Colors.black,
						Colors.blueGrey.shade900,
					],
				),
			),
			child: SingleChildScrollView(
				child: Stack(
					children: <Widget>[
					const Positioned(
						left: 5,
						top: 0,
						child: Image(
						width: 100,
						height: 100,
						image: AssetImage('assets/moon.png'),
						),
					),
					FutureBuilder<List<AlarmObject>>(
						future: alarms,
						builder: (BuildContext context, AsyncSnapshot<List<AlarmObject>> snapshot) {
							if (snapshot.hasData) {
								snapshot.data!.sort((a, b) => a.time.compareTo(b.time));
								List<DateTime> dateTimes = snapshot.data!.where((alarm) => alarm.enabled)
								.map((alarm) => alarm.getDateTime()).toList();

								String closestTime = "No Alarms Active";
								if (dateTimes.isNotEmpty) {
									DateTime closest = dateTimes.reduce((a, b) => a.difference(now).abs() < b.difference(now).abs() ? a : b);
									closestTime = "Next Alarm at ${getDateHoursMins(closest)}";

									if (closest.difference(now).inSeconds < 1) {
										ringing = snapshot.data!.where((alarm) => alarm.getDateTime() == closest).first;
									}

									if (ringing != null) {
										closestTime = "${ringing?.time} Alarm Ringing!";
									}
								}


								return Container(
									padding: const EdgeInsets.only(top: 75),
									alignment: Alignment.topCenter,
									child: Column(
										mainAxisAlignment: MainAxisAlignment.start,
										children: <Widget>[
											Text(
												currentTime,
												textAlign: TextAlign.center,
												style: const TextStyle(
													fontSize: 64,
													color: Colors.white,
													fontWeight: FontWeight.bold,
												),
											),
											Text(
												closestTime,
												textAlign: TextAlign.center,
												style: const TextStyle(
													fontSize: 16,
													color: Colors.white,
												),
											),
											if (ringing != null) TextButton(
												style: TextButton.styleFrom(
													foregroundColor: Colors.white,
													textStyle: const TextStyle(fontSize: 32)
												),
												onPressed: () async {
													await Alarm.stop(ringing?.id ?? 0);
													setState(() {
														ringing = null;
													});
												},
												child: Container(
													padding: const EdgeInsets.all(10),
													decoration: BoxDecoration(
														borderRadius: BorderRadius.circular(10),
														color: Colors.red,
													),
													child: const Text("Stop!"),

												),
											),
											Container(
												padding: const EdgeInsets.only(top: 60),
												child: Column(
													children: <Widget>[
														Container (
															margin: const EdgeInsets.all(15),
															child: 	Row(
																mainAxisAlignment: MainAxisAlignment.spaceBetween,
																children: <Widget>[
																	const Text(
																		'Alarms',
																		style: TextStyle(
																			fontSize: 24,
																			color: Colors.white,
																		),
																	),
																	Row (
																		children: <Widget>[
																			Container(
																				decoration: BoxDecoration(
																					borderRadius: BorderRadius.circular(30),
																					color: Colors.red,
																				),
																				child: IconButton(
																					onPressed: () async {
																						await clearAlarms();
																						setState(() {
																							alarms = readAlarms();
																						});
																					},
																					icon: const Icon(Icons.clear_all),
																					color: Colors.white,
																				),
																			),
																			const SizedBox(width: 15),
																			Container(
																				decoration: BoxDecoration(
																					borderRadius: BorderRadius.circular(30),
																					color: Colors.green.shade400,
																				),
																				child: IconButton(
																					onPressed: _displayNewAlarmTimePicker,
																					icon: const Icon(Icons.add),
																					color: Colors.white,
																				),
																			),
																		],
																	)
																],
															),
														),
														for (AlarmObject alarm in snapshot.data!)
															Dismissible(
																background: Container(
																	padding: const EdgeInsets.only(left: 20),
																	alignment: Alignment.centerLeft,
																	color: Colors.transparent,
																),

																secondaryBackground: Container(
																	margin: const EdgeInsets.all(15),
																	padding: const EdgeInsets.all(10),
																	alignment: Alignment.centerRight,
																	decoration: BoxDecoration(
																		borderRadius: BorderRadius.circular(10),
																		color: Colors.red,
																	),
																	child: const Icon(Icons.delete, color: Colors.white),
																),

																key: ValueKey<int>(alarm.id!),
																confirmDismiss: (DismissDirection direction) async {
																	if (direction == DismissDirection.endToStart) {
																		await deleteAlarm(alarm);
																		return true;
																	}
																	return false;
																},
																onDismissed: (DismissDirection direction) {
																	if (direction == DismissDirection.endToStart) {
																		setState(() {
																			alarms = readAlarms();
																		});
																	}
																},
																child: AlarmDisplay(alarm: alarm),
															),
														if (snapshot.data!.isEmpty) const Text("No Alarms", style: TextStyle(color: Colors.white, fontSize: 32)),
													],
												),
											),
										],
									),
								);
							} else {
								return Text("Loading...");
							}
						}
					),
				  ],
				),
			),
		),
	);
  }
}
