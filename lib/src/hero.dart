import 'package:flutter/widgets.dart';

/// Configures the [Hero] wrapper for a `ViewfinderImage` or
/// `ViewfinderItem`.
///
/// The simple case is `ViewfinderHero('photo-1')` — a tag is enough to
/// participate in the standard [Hero] flight. The named arguments expose
/// every customization Flutter's [Hero] widget offers, so callers that
/// need a custom `createRectTween`, a `flightShuttleBuilder`, or
/// `transitionOnUserGestures: true` can plug those in without dropping
/// out of the gallery.
///
/// Pass `null` for the parent's `hero` field to opt out entirely.
@immutable
class ViewfinderHero {
  const ViewfinderHero(
    this.tag, {
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.transitionOnUserGestures = false,
  });

  /// The unique tag identifying this hero in the [Hero] flight.
  final Object tag;

  /// Optional [CreateRectTween] passed straight to [Hero.createRectTween].
  final CreateRectTween? createRectTween;

  /// Optional [HeroFlightShuttleBuilder] passed straight to
  /// [Hero.flightShuttleBuilder].
  final HeroFlightShuttleBuilder? flightShuttleBuilder;

  /// Optional [HeroPlaceholderBuilder] passed straight to
  /// [Hero.placeholderBuilder].
  final HeroPlaceholderBuilder? placeholderBuilder;

  /// Forwarded to [Hero.transitionOnUserGestures]. Defaults to `false`,
  /// matching Flutter's own default.
  final bool transitionOnUserGestures;
}
