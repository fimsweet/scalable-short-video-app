import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/options_menu_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_controls_widget.dart';

class VideoScreen extends StatelessWidget {
  const VideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Video vui',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: PageView.builder(
        itemCount: 10, // Example video count
        itemBuilder: (context, index) {
          return Stack(
            children: [
              // Video player area
              Container(
                color: Colors.black,
                child: const Center(
                  child: Text(
                    'Video Player Placeholder',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              // UI Controls
              Positioned(
                bottom: 0,
                right: 0,
                child: VideoControlsWidget(
                  onCommentTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return DraggableScrollableSheet(
                          initialChildSize: 0.6,
                          minChildSize: 0.2,
                          maxChildSize: 0.9,
                          builder: (BuildContext context,
                              ScrollController scrollController) {
                            return CommentSectionWidget(
                                controller: scrollController);
                          },
                        );
                      },
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                    );
                  },
                  onMoreTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => const OptionsMenuWidget(),
                      backgroundColor: Colors.transparent,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
