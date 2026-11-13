import '../data/seed_dataset.dart';
import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/invite_model.dart';
import '../models/plan_model.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';

/// In-memory copy of the data the signed-in user can see.
///
/// With Firebase attached it is filled by [FirestoreDataStore]'s snapshot
/// listeners (scoped by role) and is never written directly by the app.
/// Without Firebase (demo builds, tests) it *is* the database: it is loaded
/// from the seed dataset and [LocalDataStore] writes to it.
///
/// Maps keep insertion order, which the UI uses as display order.
class DataCache {
  final Map<String, AppUser> users = {};

  /// Keyed by E.164 phone (the document id).
  final Map<String, UserInvite> invites = {};
  final Map<String, Barbershop> shops = {};
  final Map<String, BarbershopService> services = {};
  final Map<String, Barber> barbers = {};
  final Map<String, Booking> bookings = {};
  final Map<String, SubscriptionPlan> plans = {};

  void clear() {
    users.clear();
    invites.clear();
    shops.clear();
    services.clear();
    barbers.clear();
    bookings.clear();
    plans.clear();
  }

  void loadSeed(SeedDataset seed) {
    clear();
    for (final p in seed.plans) {
      plans[p.id] = p;
    }
    for (final u in seed.users) {
      users[u.uid] = u;
    }
    for (final s in seed.shops) {
      shops[s.id] = s;
    }
    for (final s in seed.services) {
      services[s.id] = s;
    }
    for (final b in seed.barbers) {
      barbers[b.id] = b;
    }
    for (final b in seed.bookings) {
      bookings[b.id] = b;
    }
  }
}
