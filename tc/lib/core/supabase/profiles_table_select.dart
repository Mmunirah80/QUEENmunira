import 'package:supabase_flutter/supabase_flutter.dart';

/// `profiles` SELECT for auth flows (login / session restore / chef registration load).
///
/// Use `*` so PostgREST returns whatever columns exist on `public.profiles`. A fixed
/// comma-separated list fails with `Database error querying schema` if the DB is
/// missing any named column. **Do not** add `email` here — it is not on `profiles`;
/// use [User.email] from Supabase Auth.
///
/// Nested relations are not included; chef data is loaded separately when needed.
const String kAuthProfilesSelectColumns = '*';

/// Returns the SELECT column list used for [profiles] reads during authentication.
///
/// Previously this probed multiple column sets at runtime; that could cache a bad
/// choice or fail against strict schemas. A single explicit list avoids schema errors.
Future<String> resolveProfilesSelectForAuth(SupabaseClient _) async {
  return kAuthProfilesSelectColumns;
}
