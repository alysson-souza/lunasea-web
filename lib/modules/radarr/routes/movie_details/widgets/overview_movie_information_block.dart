import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';

class RadarrMovieDetailsOverviewInformationBlock extends StatelessWidget {
  final RadarrMovie? movie;
  final RadarrQualityProfile? qualityProfile;
  final List<RadarrTag> tags;

  const RadarrMovieDetailsOverviewInformationBlock({
    Key? key,
    required this.movie,
    required this.qualityProfile,
    required this.tags,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
          title: 'monitoring',
          body: (movie?.monitored ?? false) ? 'Yes' : 'No',
        ),
        BackendPreferenceGroupContent(title: 'path', body: movie?.path),
        BackendPreferenceGroupContent(
            title: 'quality', body: qualityProfile?.name),
        BackendPreferenceGroupContent(
          title: 'availability',
          body: movie?.lunaMinimumAvailability,
        ),
        BackendPreferenceGroupContent(
            title: 'tags', body: movie?.lunaTags(tags)),
        BackendPreferenceGroupContent(title: '', body: ''),
        BackendPreferenceGroupContent(
            title: 'status', body: movie?.status?.readable),
        BackendPreferenceGroupContent(
            title: 'in cinemas', body: movie?.lunaInCinemasOn()),
        BackendPreferenceGroupContent(
          title: 'digital',
          body: movie?.lunaDigitalReleaseDate(),
        ),
        BackendPreferenceGroupContent(
          title: 'physical',
          body: movie?.lunaPhysicalReleaseDate(),
        ),
        BackendPreferenceGroupContent(
            title: 'added on', body: movie?.lunaDateAdded()),
        BackendPreferenceGroupContent(title: '', body: ''),
        BackendPreferenceGroupContent(title: 'year', body: movie?.lunaYear),
        BackendPreferenceGroupContent(title: 'studio', body: movie?.lunaStudio),
        BackendPreferenceGroupContent(
            title: 'runtime', body: movie?.lunaRuntime),
        BackendPreferenceGroupContent(
            title: 'rating', body: movie?.certification),
        BackendPreferenceGroupContent(title: 'genres', body: movie?.lunaGenres),
        BackendPreferenceGroupContent(
            title: 'alternate titles', body: movie?.lunaAlternateTitles),
      ],
    );
  }
}
