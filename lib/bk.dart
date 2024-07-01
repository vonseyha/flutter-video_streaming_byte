import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Video Streaming',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const VideoStreamScreen(),
    );
  }
}

class VideoStreamScreen extends StatefulWidget {
  const VideoStreamScreen({super.key});

  @override
  _VideoStreamScreenState createState() => _VideoStreamScreenState();
}

class _VideoStreamScreenState extends State<VideoStreamScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;
  // final int _chunkSize = 100 * 1024; // 100 KB chunks for smoother playback and logging
   final int _chunkSize = 1 * 1024 * 1024; // 1 MB chunks for efficient streaming

  @override
  void initState() {
    super.initState();
    _initializeVideoStream();
  }

  Future<void> _initializeVideoStream() async {
    try {
      final videoFile = await _fetchVideoInChunks();
      _controller = VideoPlayerController.file(videoFile);
      _initializeVideoPlayerFuture = _controller?.initialize();
      setState(() {});
    } catch (e) {
      print('Error initializing video stream: $e');
    }
  }

  Future<File> _fetchVideoInChunks() async {
    // const url = 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4';
    const url = 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4';
    final response = await http.head(Uri.parse(url));
    final contentLength = int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/temp_video.mp4');
    final raf = file.openSync(mode: FileMode.write);

    try {
      for (int i = 0; i < contentLength; i += _chunkSize) {
        final end = (i + _chunkSize < contentLength) ? i + _chunkSize : contentLength;
        final chunkResponse = await http.get(Uri.parse(url), headers: {
          'Range': 'bytes=$i-${end - 1}',
        });
        if (chunkResponse.statusCode == 206) {
          raf.writeFromSync(chunkResponse.bodyBytes);

          // Log each byte in the chunk to the console
          for (var byte in chunkResponse.bodyBytes) {
            print("byte/time fetch $byte");
          }
        } else {
          throw Exception('Failed to load video chunk');
        }
      }
    } finally {
      await raf.close();
    }
    return file;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Video Streaming'),
      ),
      body: Center(
        child: _controller != null
            ? FutureBuilder(
                future: _initializeVideoPlayerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _controller != null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}