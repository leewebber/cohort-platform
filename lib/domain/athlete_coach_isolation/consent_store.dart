import 'consent_models.dart';

class ConsentClock {
  const ConsentClock();
  DateTime now() => DateTime.now().toUtc();
}

class FixedConsentClock implements ConsentClock {
  FixedConsentClock(this._now);
  DateTime _now;
  @override
  DateTime now() => _now;
  void advance(Duration by) => _now = _now.add(by);
}

class InMemoryConsentStore {
  final invitations = <String, ConsentInvitation>{};
  final memberships = <String, ConsentMembership>{};
  final events = <ConsentAuditEvent>[];
  int _seq = 0;

  String nextId(String prefix) {
    _seq += 1;
    return '$prefix.$_seq';
  }

  ConsentInvitation? invitation(String id) => invitations[id];

  ConsentInvitation? pendingFor(String publisherId, String athleteId) {
    for (final row in invitations.values) {
      if (row.publisherId == publisherId &&
          row.athleteId == athleteId &&
          row.state == InvitationState.pending) {
        return row;
      }
    }
    return null;
  }

  ConsentMembership? activeMembership(String publisherId, String athleteId) {
    for (final row in memberships.values) {
      if (row.publisherId == publisherId &&
          row.athleteId == athleteId &&
          row.state == MembershipState.active) {
        return row;
      }
    }
    return null;
  }

  List<ConsentMembership> activeForPublisher(String publisherId) {
    return memberships.values
        .where(
          (row) =>
              row.publisherId == publisherId &&
              row.state == MembershipState.active,
        )
        .toList()
      ..sort((a, b) => b.activatedAt.compareTo(a.activatedAt));
  }

  void putInvitation(ConsentInvitation row) => invitations[row.id] = row;
  void putMembership(ConsentMembership row) => memberships[row.id] = row;

  void addEvent(ConsentAuditEvent event) {
    final exists = events.any(
      (e) =>
          e.invitationId == event.invitationId &&
          e.membershipId == event.membershipId &&
          e.transition == event.transition &&
          e.newState == event.newState,
    );
    if (!exists) events.add(event);
  }
}
