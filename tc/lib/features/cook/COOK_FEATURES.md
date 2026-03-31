# NAHAM Cook Features Reference

## Screens
| Screen | File | Status | Supabase Table | Features |
|--------|------|--------|----------------|----------|
| Home | home_screen.dart | Working | chef_profiles, orders, menu_items | Online toggle, today stats, working hours, daily capacity edit, delayed orders |
| Orders | orders_screen.dart | Working | orders, order_items | 4 tabs, 5-min timer, accept/reject, restore qty on reject, realtime |
| Order Details | order_details_screen.dart | Working | orders, order_items | Timeline, items, customer info, status buttons |
| Menu | menu_screen.dart | Working | menu_items, recipe_ingredients, orders | CRUD dishes, availability, remaining qty, active-order delete guard |
| Reels | reels_screen.dart | Working | reels, reel_likes | Feed, like, upload |
| Chat | chat_screen.dart | Working | conversations, messages, profiles | Customer chats, customer names, messages |
| Profile | profile_screen.dart | Working | chef_profiles | Edit profile, bank, vacation, health timeline, freeze/block routing |
| Bank Account | bank_account_screen.dart | Working | chef_profiles | IBAN + account name with validation |
| Documents | documents_screen.dart | Working | chef_documents | Upload status |
| Earnings | earnings_screen.dart | Working | orders, order_items | Today/weekly/monthly earnings |
| Settings | settings_screen.dart | Working | - | Toggles, support shortcuts, logout |
| Frozen | frozen_screen.dart | Working | chef_profiles | Countdown timer |
| Blocked | blocked_screen.dart | Working | - | Block message |

## Cook ↔ Customer Sync
| Cook Action | Customer Effect |
|-------------|----------------|
| Go online | Dishes appear in customer Home |
| Go offline | Dishes disappear from customer Home |
| Accept order | Customer timeline → Accepted |
| Start preparing | Customer timeline → Preparing |
| Mark ready | Customer timeline → Ready |
| Complete order | Customer timeline → Completed |
| Reject order | Customer sees Cancelled + reason + quantity restore |
| Update remaining_qty | Customer sees updated count |
| Send chat message | Customer receives message |
| Set vacation mode | Cook hidden from all customers |

## Cook ↔ Admin Sync
| Admin Action | Cook Effect |
|-------------|-------------|
| Approve cook | Cook can access dashboard |
| Reject cook | Cook sees rejection screen |
| Issue warning | warning_count increases, warning shown |
| Freeze cook | Frozen screen with countdown |
| Block cook | Blocked screen, no access |
| Inspection call | Incoming call screen (Agora) |

## Edge Cases Handled
| Case | Behavior |
|------|----------|
| No orders today | Shows empty/zero stats |
| Dish sold out | Remaining quantity shown; availability toggle supported |
| 5-min timer expires | Auto-reject order |
| Cook offline + pending orders | Warning dialog before switching offline |
| Network error | Friendly snackbar + retry flows |
| Account frozen | Countdown screen |
| Account blocked | Blocked screen + logout |
