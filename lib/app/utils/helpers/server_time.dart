/// Zona horaria de la app: siempre la del servidor (America/Monterrey),
/// sin importar la zona del teléfono.
///
/// El backend serializa las fechas con la zona de Monterrey y su offset
/// (p. ej. `2026-11-08T10:44:46-06:00`). `DateTime.parse` las convierte a UTC y,
/// al mostrarlas sin convertir, se ven 6 horas adelantadas. Aquí se recupera la
/// hora de pared de Monterrey a partir del offset que trae la propia cadena
/// (así también respeta el horario de verano de fechas anteriores a 2022).
///
/// Devuelve un `DateTime` "de pared": úsalo para mostrar con `DateFormat`,
/// no para compararlo contra `DateTime.now()` del teléfono.
DateTime? parseServerDateTime(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return null;

  final normalized =
      text.contains(' ') && !text.contains('T') ? text.replaceFirst(' ', 'T') : text;
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return null;

  // Sin offset: ya es la hora de Monterrey tal cual.
  final match = RegExp(r'([+-])(\d{2}):?(\d{2})$').firstMatch(normalized);
  if (!parsed.isUtc || match == null) return parsed;

  final sign = match.group(1) == '-' ? -1 : 1;
  final offset = Duration(
    hours: int.parse(match.group(2)!),
    minutes: int.parse(match.group(3)!),
  );
  final wall = sign < 0 ? parsed.subtract(offset) : parsed.add(offset);
  return DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute,
      wall.second, wall.millisecond);
}
