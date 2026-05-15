import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/lidarr.dart';

class LidarrDetailsOverview extends StatefulWidget {
  final LidarrCatalogueData data;

  const LidarrDetailsOverview({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  State<LidarrDetailsOverview> createState() => _State();
}

class _State extends State<LidarrDetailsOverview>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profile = context.watch<ProfilesStore>().active;
    return LunaListView(
      controller: LidarrArtistNavigationBar.scrollControllers[0],
      children: <Widget>[
        LidarrDescriptionBlock(
          title: widget.data.title,
          description: widget.data.overview == ''
              ? 'No Summary Available'
              : widget.data.overview,
          uri: widget.data.posterURI(profile),
          squareImage: true,
          headers: profile.lidarrHeaders,
        ),
        BackendPreferenceGroupCard(
          content: [
            BackendPreferenceGroupContent(
              title: 'Path',
              body: widget.data.path,
            ),
            BackendPreferenceGroupContent(
              title: 'Quality',
              body: widget.data.quality,
            ),
            BackendPreferenceGroupContent(
              title: 'Metadata',
              body: widget.data.metadata,
            ),
            BackendPreferenceGroupContent(
              title: 'Albums',
              body: widget.data.albums,
            ),
            BackendPreferenceGroupContent(
              title: 'Tracks',
              body: widget.data.tracks,
            ),
            BackendPreferenceGroupContent(
              title: 'Genres',
              body: widget.data.genre,
            ),
          ],
        ),
      ],
    );
  }
}
