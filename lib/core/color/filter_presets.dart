import 'grade.dart';

/// A named look. Presets are original to Canvo Edit and are defined entirely by
/// the same slider values users can set by hand.
class FilterPreset {
  FilterPreset(this.id, this.name, this.category, this.values)
    : matrix = matrixFromValues(values);

  final String id;
  final String name;
  final String category;
  final Map<String, double> values;
  final ColorMatrix matrix;
}

FilterPreset _f(String name, String category, Map<String, double> values) =>
    FilterPreset(name.toLowerCase().replaceAll(' ', '_'), name, category, values);

final List<FilterPreset> filterPresets = [
  FilterPreset('original', 'Original', 'All', const {}),

  // Natural
  _f('Clear Day', 'Natural', {'exposure': .08, 'contrast': .08, 'saturation': .08}),
  _f('Soft Light', 'Natural', {'exposure': .12, 'contrast': -.1, 'fade': .15}),
  _f('Morning', 'Natural', {'exposure': .1, 'temperature': .18, 'saturation': .05}),
  _f('Overcast', 'Natural', {'temperature': -.12, 'contrast': -.05, 'saturation': -.1}),
  _f('Meadow', 'Natural', {'saturation': .18, 'tint': -.18, 'contrast': .06}),
  _f('Crisp Air', 'Natural', {'contrast': .15, 'temperature': -.08, 'saturation': .1}),

  // Portrait
  _f('Glow', 'Portrait', {'exposure': .14, 'contrast': -.06, 'temperature': .12, 'fade': .08}),
  _f('Peach', 'Portrait', {'temperature': .2, 'tint': .12, 'exposure': .08, 'saturation': -.05}),
  _f('Porcelain', 'Portrait', {'exposure': .18, 'saturation': -.18, 'contrast': -.08}),
  _f('Bronze', 'Portrait', {'temperature': .3, 'contrast': .12, 'saturation': .08}),
  _f('Rose Tone', 'Portrait', {'tint': .25, 'exposure': .06, 'saturation': .04}),
  _f('Studio', 'Portrait', {'contrast': .14, 'vignette': .18, 'saturation': -.04}),

  // Film
  _f('Stock 200', 'Film', {'fade': .22, 'temperature': .12, 'saturation': -.08, 'contrast': .06}),
  _f('Stock 400', 'Film', {'fade': .3, 'temperature': .06, 'tint': -.08, 'saturation': -.12}),
  _f('Faded Reel', 'Film', {'fade': .55, 'contrast': -.1, 'saturation': -.2}),
  _f('Darkroom', 'Film', {'contrast': .22, 'fade': .12, 'vignette': .3, 'saturation': -.15}),
  _f('Slide Film', 'Film', {'contrast': .24, 'saturation': .28, 'temperature': -.05}),
  _f('Cross Lab', 'Film', {'liftB': .35, 'gainR': .2, 'gainB': -.2, 'contrast': .18}),
  _f('Pocket Cam', 'Film', {'temperature': .22, 'tint': .1, 'fade': .3, 'vignette': .35}),

  // Cinematic
  _f('Teal Amber', 'Cinematic', {'liftB': .4, 'liftG': .15, 'gainR': .18, 'gainB': -.18, 'contrast': .14}),
  _f('Blockbuster', 'Cinematic', {'liftB': .55, 'gainR': .28, 'gainB': -.24, 'contrast': .26, 'saturation': -.06}),
  _f('Noir Blue', 'Cinematic', {'saturation': -.55, 'temperature': -.3, 'contrast': .26, 'vignette': .4}),
  _f('Desert Road', 'Cinematic', {'temperature': .42, 'contrast': .2, 'saturation': -.1, 'fade': .1}),
  _f('Night Shift', 'Cinematic', {'exposure': -.25, 'liftB': .4, 'tint': -.14, 'contrast': .16}),
  _f('Epic', 'Cinematic', {'contrast': .3, 'saturation': -.14, 'vignette': .42, 'gainR': .08}),
  _f('Dune', 'Cinematic', {'temperature': .5, 'tint': .08, 'saturation': -.22, 'fade': .16}),
  _f('Matrix Code', 'Cinematic', {'tint': -.55, 'contrast': .24, 'saturation': -.25}),

  // Vivid
  _f('Pop', 'Vivid', {'saturation': .42, 'contrast': .14}),
  _f('Candy', 'Vivid', {'saturation': .36, 'tint': .2, 'exposure': .1}),
  _f('Electric', 'Vivid', {'saturation': .5, 'contrast': .22, 'temperature': -.14}),
  _f('Tropic', 'Vivid', {'saturation': .4, 'tint': -.16, 'temperature': .12}),
  _f('Sunburst', 'Vivid', {'saturation': .34, 'temperature': .36, 'exposure': .08}),
  _f('Neon', 'Vivid', {'saturation': .65, 'contrast': .3, 'hue': -8}),

  // Mono
  _f('Silver', 'Mono', {'saturation': -1, 'contrast': .08}),
  _f('Ink', 'Mono', {'saturation': -1, 'contrast': .42, 'vignette': .25}),
  _f('Ash', 'Mono', {'saturation': -1, 'fade': .35, 'contrast': -.08}),
  _f('High Key', 'Mono', {'saturation': -1, 'exposure': .34, 'contrast': -.12}),
  _f('Low Key', 'Mono', {'saturation': -1, 'exposure': -.3, 'contrast': .34}),
  _f('Selenium', 'Mono', {'saturation': -1, 'gainB': .1, 'liftB': .2, 'contrast': .12}),

  // Vintage
  _f('Sepia Print', 'Vintage', {'sepia': .85, 'fade': .15}),
  _f('Old Letter', 'Vintage', {'sepia': .5, 'fade': .3, 'vignette': .3}),
  _f('Seventies', 'Vintage', {'temperature': .34, 'tint': .14, 'fade': .3, 'saturation': -.08}),
  _f('Eighties', 'Vintage', {'saturation': .22, 'tint': .26, 'liftB': .3, 'fade': .18}),
  _f('Nineties', 'Vintage', {'fade': .2, 'tint': -.12, 'temperature': .08, 'contrast': .1}),
  _f('Polar Print', 'Vintage', {'fade': .36, 'temperature': -.12, 'tint': -.08, 'vignette': .22}),

  // Food
  _f('Fresh Plate', 'Food', {'exposure': .12, 'saturation': .2, 'temperature': .1}),
  _f('Bakery', 'Food', {'temperature': .28, 'exposure': .1, 'contrast': .05}),
  _f('Citrus', 'Food', {'saturation': .3, 'temperature': .16, 'tint': -.1}),
  _f('Espresso', 'Food', {'temperature': .24, 'contrast': .24, 'exposure': -.1}),

  // Travel
  _f('Coastline', 'Travel', {'temperature': -.2, 'saturation': .24, 'tint': -.06}),
  _f('Golden Hour', 'Travel', {'temperature': .42, 'exposure': .06, 'saturation': .12}),
  _f('Alpine', 'Travel', {'temperature': -.26, 'contrast': .2, 'saturation': .1}),
  _f('Old Town', 'Travel', {'temperature': .18, 'fade': .14, 'contrast': .1, 'saturation': -.08}),
  _f('Jungle', 'Travel', {'tint': -.26, 'saturation': .3, 'contrast': .12}),

  // Night
  _f('City Lights', 'Night', {'contrast': .22, 'saturation': .26, 'liftB': .22}),
  _f('Moonlit', 'Night', {'temperature': -.46, 'exposure': -.12, 'saturation': -.2}),
  _f('Vapor', 'Night', {'tint': .42, 'liftB': .45, 'saturation': .2, 'fade': .12}),
  _f('Afterglow', 'Night', {'tint': .2, 'temperature': .3, 'contrast': .16, 'vignette': .3}),
  _f('Lift Shadows', 'Night', {'brightness': .18, 'contrast': -.1, 'saturation': .08}),

  ..._seriesPresets(),
];

/// Base looks for the filter series. Each one is offered as-is and in every
/// treatment below, which is how the library reaches several hundred filters
/// while each stays a real, distinct set of slider values.
const _seriesBases = <(String, String, Map<String, double>)>[
  ('Azure', 'Sky', {'temperature': -.22, 'saturation': .12}),
  ('Cumulus', 'Sky', {'exposure': .1, 'temperature': -.1, 'contrast': -.06}),
  ('Dusk', 'Sky', {'tint': .18, 'temperature': .1, 'exposure': -.1}),
  ('Fern', 'Nature', {'tint': -.2, 'saturation': .2}),
  ('Moss', 'Nature', {'tint': -.28, 'saturation': -.1, 'fade': .1}),
  ('Autumn', 'Nature', {'temperature': .3, 'saturation': .2, 'tint': .06}),
  ('Concrete', 'Urban', {'saturation': -.35, 'contrast': .18}),
  ('Subway', 'Urban', {'liftB': .25, 'contrast': .16, 'saturation': -.12}),
  ('Rooftop', 'Urban', {'temperature': .12, 'contrast': .2, 'vignette': .15}),
  ('Ivory', 'Wedding', {'exposure': .16, 'saturation': -.14, 'temperature': .1}),
  ('Blush', 'Wedding', {'tint': .2, 'exposure': .12, 'contrast': -.06}),
  ('Vow', 'Wedding', {'fade': .16, 'temperature': .14, 'exposure': .06}),
  ('Runway', 'Fashion', {'contrast': .26, 'saturation': -.2}),
  ('Editorial', 'Fashion', {'contrast': .14, 'temperature': -.1, 'fade': .1}),
  ('Couture', 'Fashion', {'contrast': .22, 'tint': .1, 'vignette': .14}),
  ('Mint', 'Pastel', {'tint': -.16, 'exposure': .16, 'contrast': -.12}),
  ('Lilac', 'Pastel', {'tint': .22, 'liftB': .2, 'exposure': .12, 'contrast': -.1}),
  ('Butter', 'Pastel', {'temperature': .2, 'exposure': .22, 'contrast': -.12}),
  ('Arcade', 'Retro', {'saturation': .3, 'liftB': .24, 'contrast': .14}),
  ('Cassette', 'Retro', {'fade': .26, 'tint': .16, 'temperature': .1}),
  ('Drive In', 'Retro', {'temperature': .26, 'liftR': .2, 'fade': .16}),
  ('Ember', 'Moody', {'temperature': .26, 'exposure': -.2, 'contrast': .18}),
  ('Storm', 'Moody', {'temperature': -.24, 'exposure': -.18, 'saturation': -.2}),
  ('Velvet', 'Moody', {'tint': .22, 'exposure': -.16, 'contrast': .16}),
  ('Cyanotype', 'Creative', {'saturation': -.8, 'liftB': .5, 'gainB': .25}),
  ('Magenta Lab', 'Creative', {'saturation': -.6, 'liftR': .35, 'liftB': .35}),
  ('Copper', 'Creative', {'saturation': -.7, 'temperature': .5, 'contrast': .1}),
  ('Aurora', 'Creative', {'hue': 30, 'saturation': .2}),
  ('Infrared', 'Creative', {'hue': -70, 'saturation': .15}),
  ('Solar', 'Creative', {'hue': 18, 'temperature': .25, 'contrast': .12}),
];

const _seriesTreatments = <String, Map<String, double>>{
  'Soft': {'contrast': -.12, 'fade': .1},
  'Deep': {'contrast': .14, 'exposure': -.1},
  'Warm': {'temperature': .18},
  'Cool': {'temperature': -.18},
  'Bright': {'exposure': .18},
  'Dark': {'exposure': -.16, 'saturation': -.12, 'vignette': .22},
  'Vivid': {'saturation': .24},
  'Muted': {'saturation': -.26},
  'Faded': {'fade': .28},
  'Rose': {'tint': .18},
};

List<FilterPreset> _seriesPresets() {
  final out = <FilterPreset>[];
  for (final (name, category, values) in _seriesBases) {
    out.add(_f(name, category, values));
    _seriesTreatments.forEach((treatment, delta) {
      final merged = Map<String, double>.of(values);
      delta.forEach((key, v) {
        final param = adjustParams.firstWhere((p) => p.key == key);
        merged[key] = ((merged[key] ?? 0) + v).clamp(param.min, param.max);
      });
      out.add(_f('$name $treatment', category, merged));
    });
  }
  return out;
}

final Map<String, FilterPreset> _byId = {for (final p in filterPresets) p.id: p};

FilterPreset filterById(String id) => _byId[id] ?? filterPresets.first;

List<String> get filterCategories {
  final seen = <String>{};
  return [for (final p in filterPresets) if (seen.add(p.category)) p.category];
}
