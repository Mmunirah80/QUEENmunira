# Random live inspection — rebuild (v1)

## 1. Implementation plan

1. **Video roles (Agora)**  
   - Chef: broadcaster, local camera after explicit **Accept**.  
   - Admin: same communication profile, **local video disabled** — viewer only; remote view uses fixed chef UID `1001` (`InspectionRtcConstants.chefUid`).

2. **Navigation**  
   - Admin: Users → Inspection → **Dashboard** (start random) → **Assigned chef** → **Live viewer** → **Outcome** (full screen).  
   - Compliance: Dashboard → **Compliance & violations overview** (or History tab refresh).  
   - Chef: **Incoming** (full screen, 30s timer) → **Live camera** (after Accept) → **Result** (after finalize) + Profile/Home entry points.

3. **Supabase**  
   - No new schema in `supabase_inspection_feature_rebuild_notes_v1.sql`; rely on existing RPCs and RLS.

4. **Platform**  
   - Android: `CAMERA` + `RECORD_AUDIO` in `AndroidManifest.xml` for chef capture.

## 2. Flutter files (new / replaced)

| Area | File |
|------|------|
| RTC | `lib/features/inspection_live/inspection_rtc_constants.dart`, `inspection_rtc_helper.dart` |
| Admin | `admin_inspection_assigned_screen.dart`, `admin_inspection_live_screen.dart`, `admin_inspection_outcome_screen.dart`, `admin_compliance_overview_screen.dart` |
| Admin hub | `admin_inspections_screen.dart` (3 tabs: Applications / Dashboard / History) |
| Chef | `chef_incoming_inspection_screen.dart`, `chef_inspection_live_screen.dart`, `chef_inspection_result_screen.dart`, `chef_compliance_history_screen.dart` |
| Widgets | `chef_inspection_compliance_banner.dart`, `inspection_call_listener.dart` (rewritten) |
| Removed | `inspection_call_screen.dart`, `admin_inspection_call_screen.dart` |

## 3. Providers / datasource

- `inspectionDataSourceProvider` moved to `inspection_datasource.dart`.  
- `adminInspectionViolationsProvider` + `fetchInspectionViolationsForAdmin` in admin datasource.

## 4. SQL

- **Separate file:** `supabase_inspection_feature_rebuild_notes_v1.sql` (documentation only; no DDL).  
- Apply existing inspection migrations if not already on the project.

## 5. Schema changes

- **None** for this release (see SQL notes file).

## 6. Mock data

- No mandatory updates; use existing demo seeds only in non-prod.

## 7. Testing checklist

- [ ] Admin: Dashboard → Start random → Assigned → Live shows **Calling** then **Connected** when chef accepts.  
- [ ] Admin: **Record outcome** → only outcome + note; penalty from server.  
- [ ] Admin: Compliance overview lists `chef_violations` when violations exist.  
- [ ] Chef: Incoming → **Decline** → admin can finalize (e.g. refused / no_answer).  
- [ ] Chef: Incoming → timeout → `missed` path + admin outcome.  
- [ ] Chef: Accept → camera permission → local preview + admin sees remote (with real `AGORA_APP_ID`).  
- [ ] Chef: After finalize → full-screen result → `chef_result_seen` updated.  
- [ ] Profile: Kitchen inspections → history list.  
- [ ] Home: Warning banner when `inspection_violation_count > 0` and not frozen.
