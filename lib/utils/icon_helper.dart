import 'package:flutter/material.dart';

/// Maps stored icon code points to compile-time constant [IconData] instances.
///
/// Flutter's web release build tree-shakes the MaterialIcons font and requires
/// all [IconData] usages to be compile-time constants. Because our models store
/// icons as integer code points (for serialization), we resolve them here via a
/// static lookup table of const values instead of calling `IconData(codePoint)`
/// at runtime.
///
/// If a code point is not found in the map, [Icons.category] is used as
/// the fallback so the UI never breaks.
class IconHelper {
  IconHelper._();

  /// Returns the [IconData] corresponding to [codePoint], or [fallback] if the
  /// code point is not in the known-icons map.
  static IconData fromCodePoint(
    int codePoint, {
    IconData fallback = Icons.category,
  }) {
    return _iconMap[codePoint] ?? fallback;
  }

  /// Automatically matches category name / transaction description to a 
  /// contextually accurate Material Icon (Food -> restaurant, Credit Card Bill -> credit_card, etc.)
  static IconData getIconForCategoryName(String categoryName, {bool isIncome = false}) {
    final name = categoryName.trim().toLowerCase();
    if (name.isEmpty) {
      return isIncome ? Icons.account_balance_wallet_rounded : Icons.category_rounded;
    }

    // 1. Food, Dining & Cafe
    if (name.contains('food') || name.contains('restau') || name.contains('dini') ||
        name.contains('eat') || name.contains('cafe') || name.contains('coffe') ||
        name.contains('pizza') || name.contains('burger') || name.contains('swiggy') ||
        name.contains('zomato')) {
      return Icons.fastfood_rounded;
    }

    // 2. Credit Card & Card Bills
    if (name.contains('credit') || name.contains('card') || name.contains('cc bill') ||
        name.contains('card bill') || name.contains('statement')) {
      return isIncome ? Icons.credit_score_rounded : Icons.credit_card_rounded;
    }

    // 3. Shopping & E-Commerce
    if (name.contains('shop') || name.contains('store') || name.contains('amazon') ||
        name.contains('flipkart') || name.contains('mall') || name.contains('cloth') ||
        name.contains('apparel') || name.contains('buy')) {
      return Icons.shopping_bag_rounded;
    }

    // 4. Travel & Vehicles
    if (name.contains('travel') || name.contains('flight') || name.contains('car') ||
        name.contains('cab') || name.contains('uber') || name.contains('ola') ||
        name.contains('bus') || name.contains('train') || name.contains('commute') ||
        name.contains('taxi') || name.contains('trip')) {
      return name.contains('flight') ? Icons.flight_takeoff_rounded : Icons.directions_car_rounded;
    }

    // 5. Groceries
    if (name.contains('grocer') || name.contains('supermarket') || name.contains('veg') ||
        name.contains('fruit') || name.contains('blinkit') || name.contains('zepto') ||
        name.contains('instamart') || name.contains('mart')) {
      return Icons.local_grocery_store_rounded;
    }

    // 6. Fuel & Energy
    if (name.contains('fuel') || name.contains('petrol') || name.contains('diesel') ||
        name.contains('gas') || name.contains('cng') || name.contains('ev') || name.contains('shell')) {
      return Icons.local_gas_station_rounded;
    }

    // 7. Bills & Utilities
    if (name.contains('bill') || name.contains('utility') || name.contains('electric') ||
        name.contains('water') || name.contains('wifi') || name.contains('broadband') ||
        name.contains('recharge') || name.contains('power')) {
      return Icons.receipt_long_rounded;
    }

    // 8. Medical & Pharmacy
    if (name.contains('medic') || name.contains('health') || name.contains('doc') ||
        name.contains('hospit') || name.contains('pharm') || name.contains('clinic') ||
        name.contains('drug') || name.contains('care')) {
      return Icons.medical_services_rounded;
    }

    // 9. Education & Learning
    if (name.contains('educat') || name.contains('school') || name.contains('colleg') ||
        name.contains('tuit') || name.contains('course') || name.contains('book') ||
        name.contains('study') || name.contains('fee')) {
      return Icons.school_rounded;
    }

    // 10. Entertainment & Gaming
    if (name.contains('enter') || name.contains('movi') || name.contains('cinema') ||
        name.contains('game') || name.contains('gam') || name.contains('netflix') ||
        name.contains('hotstar') || name.contains('prime') || name.contains('music') ||
        name.contains('spotif')) {
      return (name.contains('game') || name.contains('gam'))
          ? Icons.sports_esports_rounded
          : Icons.movie_rounded;
    }

    // 11. Investment & Stock Market
    if (name.contains('invest') || name.contains('stock') || name.contains('share') ||
        name.contains('mutual') || name.contains('sip') || name.contains('trade') ||
        name.contains('crypto') || name.contains('equity') || name.contains('return')) {
      return isIncome ? Icons.trending_up_rounded : Icons.show_chart_rounded;
    }

    // 12. Rent & Housing
    if (name.contains('rent') || name.contains('house') || name.contains('flat') ||
        name.contains('room') || name.contains('pg') || name.contains('lease')) {
      return Icons.home_rounded;
    }

    // 13. Salary & Wages
    if (name.contains('salar') || name.contains('pay') || name.contains('wage') ||
        name.contains('stipend') || name.contains('income') || name.contains('earn')) {
      return Icons.account_balance_wallet_rounded;
    }

    // 14. Gift, Bonus & Cashback
    if (name.contains('gift') || name.contains('bonus') || name.contains('reward') ||
        name.contains('prize') || name.contains('cashback')) {
      return isIncome ? Icons.card_giftcard_rounded : Icons.redeem_rounded;
    }

    // 15. Money Returned & Refunds
    if (name.contains('return') || name.contains('refund') || name.contains('repay') ||
        name.contains('reimbur')) {
      return isIncome ? Icons.replay_rounded : Icons.payments_rounded;
    }

    // 16. Money Given / Lent
    if (name.contains('lent') || name.contains('borrow') || name.contains('given') ||
        name.contains('lend')) {
      return Icons.payments_rounded;
    }

    return isIncome ? Icons.account_balance_wallet_rounded : Icons.category_rounded;
  }

  // ---------------------------------------------------------------------------
  // Known MaterialIcons mapped by their code point.
  // Add any extra icons used in the app here.
  // ---------------------------------------------------------------------------
  static const Map<int, IconData> _iconMap = {
    // ── General / UI ────────────────────────────────────────────────────────
    0xe148: Icons.add,
    0xe5c3: Icons.add_circle,
    0xe5c4: Icons.add_circle_outline,
    0xe3ae: Icons.account_balance,
    0xe3af: Icons.account_balance_wallet,
    0xe853: Icons.home,
    0xe88a: Icons.settings,
    0xe5cd: Icons.close,
    0xe876: Icons.check,
    0xe5ca: Icons.check_circle,
    0xe88f: Icons.star,
    0xe838: Icons.favorite,
    0xe7f4: Icons.person,
    0xe7fb: Icons.people,
    0xe0be: Icons.email,
    0xe0cd: Icons.phone,
    0xe0c8: Icons.location_on,
    0xe8b8: Icons.search,
    0xe8b9: Icons.send,
    0xe14d: Icons.content_copy,

    // ── Finance / Money ──────────────────────────────────────────────────────
    0xe227: Icons.attach_money,
    0xe263: Icons.money_off,
    0xe57d: Icons.account_circle,
    0xe85d: Icons.payments,
    0xe59c: Icons.savings,
    0xe8a1: Icons.receipt,
    0xe8a0: Icons.receipt_long,
    0xe00e: Icons.credit_card,
    0xe8f0: Icons.wallet,
    0xe0d6: Icons.currency_exchange,
    0xf04b4: Icons.currency_rupee,
    0xf04b5: Icons.currency_pound,
    0xe14f: Icons.euro_symbol,
    0xe8ef: Icons.price_check,
    0xe8ec: Icons.price_change,

    // ── Categories ──────────────────────────────────────────────────────────
    0xe574: Icons.category,
    0xe532: Icons.label,
    0xe892: Icons.tag,
    0xe53f: Icons.local_grocery_store,
    0xe546: Icons.local_hospital,
    0xe549: Icons.local_mall,
    0xe553: Icons.local_pharmacy,
    0xe556: Icons.local_pizza,
    0xe557: Icons.local_play,
    0xe558: Icons.local_police,
    0xe55a: Icons.local_printshop,
    0xe55f: Icons.local_shipping,
    0xe560: Icons.local_taxi,
    0xe57a: Icons.fastfood,
    0xe906: Icons.restaurant,
    0xe907: Icons.restaurant_menu,
    0xe8d1: Icons.school,
    0xe0cc: Icons.phone_android,
    0xe334: Icons.directions_car,
    0xe530: Icons.flight,
    0xe8f5: Icons.work,
    0xe87c: Icons.laptop,
    0xe87d: Icons.laptop_mac,
    0xe315: Icons.fitness_center,
    0xe3f4: Icons.sports_esports,
    0xe8f8: Icons.subscriptions,
    0xe8db: Icons.shopping_bag,
    0xe8cc: Icons.shopping_basket,
    0xe8cd: Icons.shopping_cart,
    0xe03e: Icons.movie,
    0xe030: Icons.music_note,
    0xe87e: Icons.library_books,
    0xe865: Icons.medical_services,
    0xe9e0: Icons.health_and_safety,
    0xe420: Icons.child_care,
    0xe7fe: Icons.pets,
    0xe1bc: Icons.directions_bus,
    0xe56b: Icons.train,
    0xe539: Icons.local_gas_station,
    0xe1d8: Icons.house,
    0xe3a5: Icons.palette,
    0xe40a: Icons.sports,
    0xe9aa: Icons.volunteer_activism,
    0xe9c9: Icons.water_drop,
    0xe8a2: Icons.redeem,
    0xf04b2: Icons.card_giftcard,
    0xe8a4: Icons.remove_shopping_cart,

    // ── Charts / Analytics ──────────────────────────────────────────────────
    0xe24b: Icons.bar_chart,
    0xe6e1: Icons.pie_chart,
    0xe4e8: Icons.show_chart,
    0xe8e5: Icons.trending_up,
    0xe8e6: Icons.trending_down,
    0xe8e7: Icons.trending_flat,
    0xe801: Icons.analytics,
    0xe80c: Icons.assessment,
    0xe3e4: Icons.insights,

    // ── Misc ─────────────────────────────────────────────────────────────────
    0xe894: Icons.today,
    0xe916: Icons.event,
    0xe8df: Icons.schedule,
    0xe8b5: Icons.notifications,
    0xe7f3: Icons.lock,
    0xe9e7: Icons.share,
    0xe14c: Icons.content_cut,
    0xe14e: Icons.content_paste,
    0xe87b: Icons.help,
    0xe88e: Icons.info,
    0xe000: Icons.error,
    0xe8b2: Icons.warning,
    0xe5c9: Icons.delete,
    0xe3c9: Icons.edit,
    0xe5d3: Icons.filter_list,
    0xe152: Icons.sort,
    0xe8ee: Icons.visibility,
    0xe8f4: Icons.visibility_off,
    0xe5d5: Icons.expand_more,
    0xe5cf: Icons.expand_less,
    0xe5cc: Icons.menu,
    0xe5c5: Icons.arrow_back,
    0xe5c8: Icons.arrow_forward,
    0xe317: Icons.keyboard_arrow_up,
    0xe316: Icons.keyboard_arrow_down,
    0xe5db: Icons.refresh,
    0xe86c: Icons.power_settings_new,
  };
}
