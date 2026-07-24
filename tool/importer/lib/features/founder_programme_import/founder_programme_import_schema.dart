/// Founder Programme Importer YAML schema (V1).
class FounderProgrammeImportSchema {
  FounderProgrammeImportSchema._();

  static const supportedSchemaVersion = 1;

  static const allowedSessionTypes = {
    'strength',
    'accessory',
    'conditioning',
    'circuit',
    'running',
    'intervals',
    'recovery',
    'skill',
    'core',
  };

  static const allowedBlockTypes = {
    'warm_up',
    'strength',
    'skill',
    'accessory',
    'conditioning',
    'core',
    'cool_down',
    'custom',
  };
}
