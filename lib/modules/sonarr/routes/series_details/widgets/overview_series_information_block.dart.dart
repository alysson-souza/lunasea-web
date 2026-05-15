import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/modules/sonarr.dart';

class SonarrSeriesDetailsOverviewInformationBlock extends StatelessWidget {
  final SonarrSeries? series;
  final SonarrQualityProfile? qualityProfile;
  final SonarrLanguageProfile? languageProfile;
  final List<SonarrTag> tags;

  const SonarrSeriesDetailsOverviewInformationBlock({
    Key? key,
    required this.series,
    required this.qualityProfile,
    required this.languageProfile,
    required this.tags,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
          title: 'sonarr.Monitoring'.tr(),
          body: (series?.monitored ?? false) ? 'Yes' : 'No',
        ),
        BackendPreferenceGroupContent(
          title: 'type',
          body: series?.lunaSeriesType,
        ),
        BackendPreferenceGroupContent(
          title: 'path',
          body: series?.path,
        ),
        BackendPreferenceGroupContent(
          title: 'quality',
          body: qualityProfile?.name,
        ),
        BackendPreferenceGroupContent(
          title: 'language',
          body: languageProfile?.name,
        ),
        BackendPreferenceGroupContent(
          title: 'tags',
          body: series?.lunaTags(tags),
        ),
        BackendPreferenceGroupContent(title: '', body: ''),
        BackendPreferenceGroupContent(
          title: 'status',
          body: series?.status?.toTitleCase(),
        ),
        BackendPreferenceGroupContent(
          title: 'next airing',
          body: series?.lunaNextAiring(),
        ),
        BackendPreferenceGroupContent(
          title: 'added on',
          body: series?.lunaDateAdded,
        ),
        BackendPreferenceGroupContent(title: '', body: ''),
        BackendPreferenceGroupContent(
          title: 'year',
          body: series?.lunaYear,
        ),
        BackendPreferenceGroupContent(
          title: 'network',
          body: series?.lunaNetwork,
        ),
        BackendPreferenceGroupContent(
          title: 'runtime',
          body: series?.lunaRuntime,
        ),
        BackendPreferenceGroupContent(
          title: 'rating',
          body: series?.certification,
        ),
        BackendPreferenceGroupContent(
          title: 'genres',
          body: series?.lunaGenres,
        ),
        BackendPreferenceGroupContent(
          title: 'alternate titles',
          body: series?.lunaAlternateTitles,
        ),
      ],
    );
  }
}
