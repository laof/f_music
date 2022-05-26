import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'common.dart';
import 'package:rxdart/rxdart.dart';

import 'search.dart';

var cc = Uri.parse(
    "https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg");

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = "歡迎使用";
  static int _nextMediaId = 0;
  late AudioPlayer _player;
  int _addedCount = 0;

  final _playlist = ConcatenatingAudioSource(children: []);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.red,
    ));
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });

    try {
      await _player.setAudioSource(_playlist);
    } catch (e, stackTrace) {
      // Catch load errors: 404, invalid url ...
      print("Error loading playlist: $e");
      print(stackTrace);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _play(String token, name, author) async {
    setState(() {
      _status = "加載 $name ..";
    });

    var url = await getMP3(token);

    if (url == "") {
      setState(() {
        _status = "播放: $name 失敗";
      });
      return;
    }

    try {
      // await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      // _player.play();

      await _playlist.add(AudioSource.uri(Uri.parse(url),
          tag: MediaItem(
            id: '${_nextMediaId++}',
            album: author,
            title: name,
            artUri: cc,
          )));

      if (_player.playing) {
        _player.seekToNext();
        // _player.seek(Duration.zero, index: _nextMediaId);
      } else {
        _player.play();
      }
    } catch (e) {
      print("Error loading audio source: $e");
    }

    setState(() {
      _status = name;
    });
  }

  var keyword = "";
  List<Widget> list = [];

  void _search() async {
    setState(() {
      _status = "搜索 $keyword ..";
    });

    List res = await search(keyword);
    List<Widget> arr = [];

    res.forEach((obj) {
      var txt = "${obj["index"] + 1} ${obj["name"]}";

      var item = Row(children: [
        Expanded(
            flex: 2,
            child: Row(
              children: [
                InkWell(
                    child: Container(
                      padding: const EdgeInsets.only(
                        bottom: 5,
                        top: 5,
                      ),
                      child: Text(
                        txt,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                        ),
                        softWrap: true,
                      ),
                    ),
                    onTap: () {
                      _play(obj["token"], obj["name"], obj["author"]);
                    }),
                Expanded(
                  child: Text(''),
                )
              ],
            )),
        Expanded(
            flex: 1,
            child: Text(
              obj["author"],
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.grey,
              ),
              softWrap: true,
            )),
      ]);

      var padding = Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: item,
      );

      arr.add(padding);
    });
    setState(() {
      list = arr;
      _status = "找到: $keyword ${arr.length}條";
    });
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.red,
      theme: ThemeData(primarySwatch: Colors.red),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // FocusScope.of(context).unfocus();
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: Center(
                // Center is a layout widget. It takes a single child and positions it
                // in the middle of the parent.
                child: SafeArea(
                  child: Container(
                    alignment: Alignment.center,
                    child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1, bottom: 1),
                              child: TextField(
                                autofocus: false,
                                decoration: const InputDecoration(
                                    hintStyle: TextStyle(fontSize: 16),
                                    hintText: '请输入'),
                                onChanged: (newValue) {
                                  keyword = newValue;
                                },
                                keyboardType: TextInputType.text,
                                onSubmitted: (value) {
                                  FocusScope.of(context)
                                      .requestFocus(FocusNode());

                                  if (value == "") {
                                    return;
                                  }

                                  _search();
                                },
                              ),
                            ),
                            Expanded(
                              child: ListView(children: [
                                ...list,
                              ]),
                            ),
                            ControlButtons(_player),
                            StreamBuilder<PositionData>(
                              stream: _positionDataStream,
                              builder: (context, snapshot) {
                                final positionData = snapshot.data;
                                return SeekBar(
                                  duration:
                                      positionData?.duration ?? Duration.zero,
                                  position:
                                      positionData?.position ?? Duration.zero,
                                  bufferedPosition:
                                      positionData?.bufferedPosition ??
                                          Duration.zero,
                                  onChangeEnd: (newPosition) {
                                    _player.seek(newPosition);
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 8.0),
                            Row(
                              children: [
                                StreamBuilder<LoopMode>(
                                  stream: _player.loopModeStream,
                                  builder: (context, snapshot) {
                                    final loopMode =
                                        snapshot.data ?? LoopMode.off;
                                    const icons = [
                                      Icon(Icons.repeat, color: Colors.grey),
                                      Icon(Icons.repeat,
                                          color: Colors.blueAccent),
                                      Icon(Icons.repeat_one,
                                          color: Colors.blueAccent),
                                    ];
                                    const cycleModes = [
                                      LoopMode.off,
                                      LoopMode.all,
                                      LoopMode.one,
                                    ];
                                    final index = cycleModes.indexOf(loopMode);
                                    return IconButton(
                                      icon: icons[index],
                                      onPressed: () {
                                        _player.setLoopMode(cycleModes[
                                            (cycleModes.indexOf(loopMode) + 1) %
                                                cycleModes.length]);
                                      },
                                    );
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    _status,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                StreamBuilder<bool>(
                                  stream: _player.shuffleModeEnabledStream,
                                  builder: (context, snapshot) {
                                    final shuffleModeEnabled =
                                        snapshot.data ?? false;
                                    return IconButton(
                                      icon: shuffleModeEnabled
                                          ? const Icon(Icons.shuffle,
                                              color: Colors.blueAccent)
                                          : const Icon(Icons.shuffle,
                                              color: Colors.grey),
                                      onPressed: () async {
                                        final enable = !shuffleModeEnabled;
                                        if (enable) {
                                          await _player.shuffle();
                                        }
                                        await _player
                                            .setShuffleModeEnabled(enable);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        )),
                    decoration: const BoxDecoration(
                      color: Colors.black12,
                    ),
                  ),
                ),
              ))),
    );
  }
}

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 16,
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, snapshot) => IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: player.hasPrevious ? player.seekToPrevious : null,
          ),
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;

            // return Container(
            //   width: 34.0,
            //   height: 34.0,
            //   child: Container(
            //     margin: const EdgeInsets.all(8.0),
            //     child: const CircularProgressIndicator(strokeWidth:3),
            //   ),
            // );

            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                width: 34.0,
                height: 34.0,
                child: Container(
                  margin: const EdgeInsets.all(8.0),
                  child: const CircularProgressIndicator(strokeWidth: 3),
                ),
              );
            } else if (playing != true) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                // iconSize: 34.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: const Icon(Icons.pause),
                // iconSize: 34.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.replay),
                // iconSize: 34.0,
                onPressed: () => player.seek(Duration.zero,
                    index: player.effectiveIndices!.first),
              );
            }
          },
        ),
        StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, snapshot) => IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: player.hasNext ? player.seekToNext : null,
          ),
        ),
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}
