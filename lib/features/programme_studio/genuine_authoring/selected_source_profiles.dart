import 'native_session_source.dart';

const hybridSourceDirectory =
    'docs/programmes/hybrid_10k/performance_selected_2026_11_03';
const archivedHybridSourceDirectory =
    'docs/programmes/hybrid_10k/founder_selected_2026_10_30';
const selectedSourceFiles = <String>[
  'SOURCE.json',
  'SCHEDULE_CANDIDATE.json',
  'STRENGTH_REVIEW_GRAPHS.json',
  'RUNNING_BODIES.json',
  'IDENTITY_INTAKE.json',
];

const selectedSourcePins = <String, Map<String, String>>{
  'docs/programmes/hybrid_10k/performance_selected_2026_11_03': {
    'SOURCE.json':
        '96db2300a2c84f38b745bbf9f04743f857a96b768b5a7a94ef1690428fb6a0b2',
    'SCHEDULE_CANDIDATE.json':
        '1177f92cc3f9adec1a6ab96bbc64661ed9aff66347ae39d873efd220d571df9f',
    'STRENGTH_REVIEW_GRAPHS.json':
        '399fcdcf618ee85d474e973d0a53a3a950f052740d7b539056df95ed1517342e',
    'RUNNING_BODIES.json':
        '38f9224913767959218b91468142cba498a772080a35fae52cf162468ca8ffef',
    'IDENTITY_INTAKE.json':
        '5372a05dda6c2a4850794b94bb3c6beed654cbc55a2fc972ea1e8ab1c8f68652',
  },
  'docs/programmes/hybrid_10k/founder_selected_2026_10_30': {
    'SOURCE.json':
        'f12b5df97f0a9dc813c9610021ee82233414d2e2b1e6187dd0ae09745e3ecdf5',
    'SCHEDULE_CANDIDATE.json':
        '4276d149c61e9d5c476593da9360821a2bc5fe8b9bad896b7346f0e25fd4f02c',
    'STRENGTH_REVIEW_GRAPHS.json':
        '399fcdcf618ee85d474e973d0a53a3a950f052740d7b539056df95ed1517342e',
    'RUNNING_BODIES.json':
        '5d36176a57d8b610799cd72bf8be452bbf9a68fa7396ce4bf41877f83959491b',
    'IDENTITY_INTAKE.json':
        '5372a05dda6c2a4850794b94bb3c6beed654cbc55a2fc972ea1e8ab1c8f68652',
  },
};

String verifiedSourceDirectory(Map<String, String> sources) {
  for (final profile in selectedSourcePins.entries) {
    if (sources.length == profile.value.length &&
        profile.value.entries.every(
          (pin) =>
              sources[pin.key] != null &&
              nativeDigest(sources[pin.key]!) == pin.value,
        )) {
      return profile.key;
    }
  }
  throw const FormatException('Selected source bytes changed.');
}
