import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'common.dart';
import 'package:rxdart/rxdart.dart';

import 'search.dart';

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

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
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
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  create(String url) async {
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      _player.play();
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  void _play(String token, name) async {
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

    await create(url);

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
      arr.add(TextButton(
        onPressed: () {
          _play(obj["token"], obj["name"]);
        },
        child: Text(obj["name"]),
      ));
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
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
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
                                      Icon(Icons.repeat, color: Colors.orange),
                                      Icon(Icons.repeat_one,
                                          color: Colors.orange),
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
                                              color: Colors.orange)
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
                // floatingActionButton: FloatingActionButton(
                //   child: const Icon(Icons.add),
                //   onPressed: () {
                //     _playlist.add(AudioSource.uri(
                //       Uri.parse("asset:///audio/nature.mp3"),
                //       tag: MediaItem(
                //         id: '${_nextMediaId++}',
                //         album: "Public Domain",
                //         title: "Nature Sounds ${++_addedCount}",
                //         artUri: Uri.parse(
                //             "https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg"),
                //       ),
                //     ));
                //   },
                // ),
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
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: const Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
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
