<?php
// ================== MAXSUS DASTURLAR + TO'LOV USULLARI MODULI ==================
// bot.php ichidan, update ($up) o'qilgandan keyin require qilinadi.
// O'ziga tegishli bo'lsa — ishlaydi va exit; aks holda return (bot.php davom etadi).

if (!isset($up)) return;

// ---- Telegram Yulduz (Stars): pre-checkout'ni darhol tasdiqlash ----
if (isset($up['pre_checkout_query'])) {
    bot('answerPreCheckoutQuery', ['pre_checkout_query_id' => $up['pre_checkout_query']['id'], 'ok' => true]);
    exit;
}

function pc_norm_device($t)
{
    $h = strtoupper(preg_replace('/[^0-9A-Fa-f]/', '', (string)$t));
    if (strlen($h) < 8) return '';
    $h = substr($h, 0, 8);
    return substr($h, 0, 4) . '-' . substr($h, 4, 4);
}
function pc_secret_of($p) { return (!empty($p['lic']['secret'])) ? $p['lic']['secret'] : PC_SECRET; }

// ---- Yulduz (Stars) hisob-kitobi va invoys ----
function pc_stars($som)
{
    $rate = (int)setting('stars_rate', 200);
    if ($rate < 1) $rate = 200;
    $s = (int)ceil($som / $rate);
    return $s < 1 ? 1 : $s;
}
function pc_send_invoice($chat, $oid, $amount, $title)
{
    $lbl = mb_substr($title, 0, 32);
    $stars = pc_stars($amount);
    $r = bot('sendInvoice', [
        'chat_id' => $chat,
        'title' => $lbl,
        'description' => mb_substr($title, 0, 255),
        'payload' => (string)$oid,
        'currency' => 'XTR',
        'prices' => json_encode([['label' => $lbl, 'amount' => $stars]]),
    ]);
    if (empty($r['ok'])) send($chat, "⚠️ Yulduz orqali to'lovni ochib bo'lmadi. Boshqa usulni tanlang yoki keyinroq urinib ko'ring.");
}

// ---- Admin: to'lov sozlamalari menyusi (3 usul) ----
function pc_pay_menu($chat, $mid = null)
{
    $mode = pay_mode();
    $modeName = $mode == 'vipay' ? 'ViPay (avtomatik)' : ($mode == 'stars' ? 'Telegram Yulduz (Stars)' : 'Karta + chek (qo\'lda)');
    $key = setting('vipay_key', VIPAY_KEY);
    $rate = (int)setting('stars_rate', 200);
    $t = "💳 <b>To'lov sozlamalari</b>\n\nJoriy rejim: <b>" . $modeName . "</b>\n\n🔑 ViPay kalit: " . ($key ? '✅ bor' : "yo'q ❌") .
        "\n💳 Karta: " . esc(setting('card', MANUAL_CARD) ?: "yo'q") . "\n👤 Egasi: " . esc(setting('card_owner', MANUAL_CARD_OWNER)) .
        "\n⭐ Yulduz kursi: 1 ⭐ = " . money($rate);
    $k = [
        [['text' => ($mode == 'vipay' ? '🟢 ' : '') . 'ViPay (avtomatik)', 'callback_data' => 'pcpay:vipay']],
        [['text' => ($mode == 'stars' ? '🟢 ' : '') . 'Telegram Yulduz (Stars)', 'callback_data' => 'pcpay:stars']],
        [['text' => ($mode == 'manual' ? '🟢 ' : '') . 'Karta + chek (qo\'lda)', 'callback_data' => 'pcpay:manual']],
        [['text' => '🔑 ViPay kalit', 'callback_data' => 'pcset:vipay_key']],
        [['text' => '💳 Karta raqami', 'callback_data' => 'pcset:card'], ['text' => '👤 Karta egasi', 'callback_data' => 'pcset:card_owner']],
        [['text' => '⭐ Yulduz kursi', 'callback_data' => 'pcset:stars_rate']],
    ];
    show($chat, $mid, $t, ['inline_keyboard' => $k]);
}

// Litsenziya to'lovini boshlaydi (ViPay / Yulduz / Karta+chek)
function pc_start_license_payment($chat, $uid, $price, $pid, $title, $days, $device, $secret)
{
    $oid = date('ymdHis') . rand(100, 999);
    $o = ['id' => $oid, 'uid' => $uid, 'type' => 'license', 'pid' => $pid, 'amount' => $price, 'title' => $title, 'status' => 'pending', 'created' => time(), 'days' => $days, 'device' => $device, 'secret' => $secret];

    if (pay_mode() == 'stars') {
        order_save($oid, $o);
        pc_send_invoice($chat, $oid, $price, $title);
        return;
    }
    if (pay_mode() == 'vipay') {
        $r = vipay_create($oid, $price, $title);
        if (!$r['ok']) return send($chat, "⚠️ To'lov tizimida xatolik: " . esc($r['error']) . "\nBirozdan so'ng qayta urinib ko'ring.");
        $o['vipay_id'] = $r['id'];
        $o['pay_amount'] = $r['amount'];
        $t = "🧾 <b>Buyurtma #$oid</b>\n📦 " . esc($title) . "\n📱 Qurilma: <code>" . esc($device) . "</code>\n💵 To'lov summasi: <b>" . money($r['amount']) . "</b>\n";
        if ($r['card']) $t .= "💳 Karta: <code>" . esc($r['card']) . "</code>\n\n⚠️ Aynan shu summani <b>5 daqiqa</b> ichida o'tkazing, aks holda to'lov avtomatik aniqlanmaydi.\n";
        $t .= "\nTo'lovdan so'ng «✅ To'lovni tekshirish» ni bosing.";
        $k = [];
        if ($r['url']) $k[] = [['text' => "💳 To'lash", 'url' => $r['url']]];
        $k[] = [['text' => "✅ To'lovni tekshirish", 'callback_data' => "chk:$oid"]];
        $k[] = [['text' => '❌ Bekor qilish', 'callback_data' => "cnl:$oid"]];
        order_save($oid, $o);
        send($chat, $t, ['inline_keyboard' => $k]);
    } else {
        if (!setting('card', MANUAL_CARD)) { notify_admins("⚠️ Xaridor to'lov qilmoqchi, lekin to'lov sozlanmagan!"); return send($chat, "⏳ To'lov tizimi hozircha sozlanmoqda. Birozdan so'ng urinib ko'ring."); }
        $t = "🧾 <b>Buyurtma #$oid</b>\n📦 " . esc($title) . "\n📱 Qurilma: <code>" . esc($device) . "</code>\n💵 Summa: <b>" . money($price) . "</b>\n\n💳 Karta: <code>" . setting('card', MANUAL_CARD) . "</code>\n👤 " . setting('card_owner', MANUAL_CARD_OWNER) . "\n\nTo'lovni qilib «🧾 Chek yuborish» ni bosing va chek rasmini yuboring. Admin tasdiqlagach kalit avtomatik keladi.";
        $k = [[['text' => '🧾 Chek yuborish', 'callback_data' => "cheque:$oid"]], [['text' => '❌ Bekor qilish', 'callback_data' => "cnl:$oid"]]];
        order_save($oid, $o);
        send($chat, $t, ['inline_keyboard' => $k]);
    }
}

function pc_show_product($chat, $mid, $pid, $uid)
{
    $p = products()['items'][$pid] ?? null;
    if (!$p) return show($chat, $mid, "❌ Dastur topilmadi yoki o'chirilgan.");
    $u = user_get($uid);
    $owned = in_array($pid, $u['bought'] ?? []);
    $p180 = (int)($p['lic']['p180'] ?? 0);
    $p365 = (int)($p['lic']['p365'] ?? 0);
    $t = "<b>" . esc($p['name']) . "</b>\n\n" . esc(mb_substr($p['desc'], 0, 650)) .
        "\n\n🖥 Platforma: " . esc($p['platform']) .
        ($p['version'] ? "\n🏷 Versiya: " . esc($p['version']) : '') .
        "\n📥 Yuklab olingan: " . $p['sales'] . " marta" .
        "\n💵 APK narxi: <b>" . ($p['price'] > 0 ? money($p['price']) : 'Bepul') . "</b>" .
        ($owned ? "\n\n✅ Siz bu dasturni sotib olgansiz." : '');
    $k = [];
    if ($p['price'] == 0 || $owned) $k[] = [['text' => '📥 APK yuklab olish', 'callback_data' => "get:$pid"]];
    else $k[] = [['text' => "💳 APK sotib olish — " . money($p['price']), 'callback_data' => "buy:$pid"]];
    if ($p180 > 0) $k[] = [['text' => "🔑 6 oylik litsenziya — " . money($p180), 'callback_data' => "lic:$pid:180"]];
    if ($p365 > 0) $k[] = [['text' => "🔑 1 yillik litsenziya — " . money($p365), 'callback_data' => "lic:$pid:365"]];
    $k[] = [['text' => '♻️ PIN kodni tiklash', 'callback_data' => "pinr:$pid"]];
    $contact = setting('admin_contact', '');
    if ($contact) $k[] = [['text' => "👨‍💻 Admin bilan bog'lanish", 'url' => (strpos($contact, 'http') === 0 ? $contact : 'https://t.me/' . ltrim($contact, '@'))]];
    $k[] = [['text' => '🔙 Orqaga', 'callback_data' => "cat:special:0"]];
    if (is_admin($uid)) {
        $k[] = [['text' => '✏️ APK narx', 'callback_data' => "aprice:$pid"], ['text' => "🗑 O'chirish", 'callback_data' => "adel:$pid"]];
        $k[] = [['text' => '✏️ 6 oy narx', 'callback_data' => "licset:$pid:180"], ['text' => '✏️ 1 yil narx', 'callback_data' => "licset:$pid:365"]];
    }
    if ($p['photo']) {
        if ($mid) bot('deleteMessage', ['chat_id' => $chat, 'message_id' => $mid]);
        bot('sendPhoto', ['chat_id' => $chat, 'photo' => $p['photo'], 'caption' => $t, 'parse_mode' => 'HTML', 'reply_markup' => json_encode(['inline_keyboard' => $k])]);
    } else show($chat, $mid, $t, ['inline_keyboard' => $k]);
}

// ---------- CALLBACK ----------
if (isset($up['callback_query'])) {
    $cq = $up['callback_query'];
    $data = $cq['data'];
    $uid = $cq['from']['id'];
    $chat = $cq['message']['chat']['id'];
    $mid = $cq['message']['message_id'];
    @list($act, $a, $b) = explode(':', $data);

    if ($act == 'pcpay') {
        if (!is_admin($uid)) return;
        if ($a == 'vipay' && !setting('vipay_key', VIPAY_KEY)) { answer($cq['id'], "Avval ViPay kalitini kiriting", true); exit; }
        if ($a == 'manual' && !setting('card', MANUAL_CARD)) { answer($cq['id'], "Avval karta raqamini kiriting", true); exit; }
        setting_set('pay_mode', $a);
        answer($cq['id'], "✅ O'zgartirildi");
        pc_pay_menu($chat, $mid);
        exit;
    }
    if ($act == 'pcset') {
        if (!is_admin($uid)) return;
        answer($cq['id']);
        set_step($uid, "pcset:$a");
        $hint = ['vipay_key' => "🔑 ViPay API kalitini yuboring:", 'card' => '💳 Karta raqamini yuboring:', 'card_owner' => '👤 Karta egasining ismini yuboring:', 'stars_rate' => "⭐ 1 Yulduz necha so'mligini yozing (masalan 200):"];
        send($chat, $hint[$a] ?? 'Qiymat yuboring:', cancel_kb());
        exit;
    }

    if ($act == 'p') {
        $p = products()['items'][(int)$a] ?? null;
        if ($p && $p['cat'] == 'special') { answer($cq['id']); pc_show_product($chat, $mid, (int)$a, $uid); exit; }
        return;
    }

    // Yulduz rejimida xaridni ushlab olish (har qanday mahsulot)
    if ($act == 'buy' && pay_mode() == 'stars') {
        $pid = (int)$a;
        $p = products()['items'][$pid] ?? null;
        if (!$p) { answer($cq['id'], 'Topilmadi', true); exit; }
        answer($cq['id']);
        $oid = date('ymdHis') . rand(100, 999);
        $o = ['id' => $oid, 'uid' => $uid, 'type' => 'product', 'pid' => $pid, 'amount' => $p['price'], 'title' => $p['name'], 'status' => 'pending', 'created' => time()];
        order_save($oid, $o);
        pc_send_invoice($chat, $oid, $p['price'], $p['name']);
        exit;
    }

    if ($act == 'lic') {
        $pid = (int)$a; $days = (int)$b;
        answer($cq['id']);
        set_step($uid, "licdev:$pid:$days");
        send($chat, "🔑 <b>" . ($days == 365 ? "1 yillik" : "6 oylik") . " litsenziya</b>\n\nIlovada «💳 Tarif va litsenziya» bo'limini oching va <b>QURILMA KODINGIZNI</b> shu yerga yuboring.\nMasalan: <code>7F3A-91BC</code>", cancel_kb());
        exit;
    }
    if ($act == 'pinr') {
        $pid = (int)$a;
        $u = user_get($uid);
        answer($cq['id']);
        if (!in_array($pid, $u['bought'] ?? [])) { send($chat, "❗ PIN tiklash faqat ushbu dasturni sotib olganlar uchun. Avval sotib oling."); exit; }
        set_step($uid, "pinrst:$pid");
        send($chat, "♻️ <b>PIN kodni tiklash</b>\n\nIlovadagi «PIN esimdan chiqdi» bo'limidagi <b>reset-kodni</b> shu yerga yuboring.\nMasalan: <code>7F3A-91BC</code>", cancel_kb());
        exit;
    }
    if ($act == 'licset') {
        if (!is_admin($uid)) return;
        answer($cq['id']);
        set_step($uid, "licprice:$a:$b");
        send($chat, "💵 " . ($b == 365 ? "1 yillik" : "6 oylik") . " tarif narxini yozing (so'mda, 0 — o'chirish):", cancel_kb());
        exit;
    }
    return;
}

// ---------- XABAR / QADAM ----------
if (isset($up['message'])) {
    $m = $up['message'];
    if (($m['chat']['type'] ?? '') != 'private') return;
    $chat = $m['chat']['id'];
    $uid = $m['from']['id'];

    // Yulduz to'lovi muvaffaqiyatli — buyurtmani yakunlaymiz
    if (isset($m['successful_payment'])) {
        complete_order($m['successful_payment']['invoice_payload']);
        exit;
    }

    $text = $m['text'] ?? '';
    $u = user_get($uid);
    if (!$u) return;
    $step = $u['step'] ?? '';
    if ($text == '❌ Bekor qilish') return;

    // Admin: to'lov sozlamalari menyusi (bot.php'dagidan ustun)
    if ($text == "💳 To'lov sozlamalari" && is_admin($uid)) { pc_pay_menu($chat); exit; }

    // Admin: to'lov sozlamasi qiymatini saqlash
    if (strpos($step, 'pcset:') === 0) {
        if (!is_admin($uid)) { set_step($uid, ''); return; }
        $key = substr($step, 6);
        if ($text === '') { send($chat, "Qiymat yuboring:"); exit; }
        setting_set($key, trim($text));
        if ($key == 'vipay_key') { bot('deleteMessage', ['chat_id' => $chat, 'message_id' => $m['message_id']]); if (!setting('pay_mode')) setting_set('pay_mode', 'vipay'); }
        set_step($uid, '');
        send($chat, "✅ Saqlandi.", admin_kb());
        pc_pay_menu($chat);
        exit;
    }

    // Donat — Yulduz rejimida
    if ($step == 'donate' && pay_mode() == 'stars') {
        $sum = (int)preg_replace('/\D/', '', $text);
        if ($sum < MIN_DONATE) { send($chat, "❗ Eng kam summa: " . money(MIN_DONATE) . ". Raqam bilan yozing:"); exit; }
        set_step($uid, '');
        $oid = date('ymdHis') . rand(100, 999);
        $o = ['id' => $oid, 'uid' => $uid, 'type' => 'donate', 'pid' => null, 'amount' => $sum, 'title' => 'Donat', 'status' => 'pending', 'created' => time()];
        order_save($oid, $o);
        send($chat, "💝 Rahmat!", main_kb($uid));
        pc_send_invoice($chat, $oid, $sum, 'Donat');
        exit;
    }

    if (strpos($step, 'licdev:') === 0) {
        @list(, $pid, $days) = explode(':', $step);
        $dev = pc_norm_device($text);
        if (!$dev) { send($chat, "❗ Qurilma kodi noto'g'ri. Masalan: <code>7F3A-91BC</code>"); exit; }
        $p = products()['items'][(int)$pid] ?? null;
        if (!$p) { set_step($uid, ''); send($chat, "❌ Dastur topilmadi.", main_kb($uid)); exit; }
        $price = $days == 365 ? (int)($p['lic']['p365'] ?? 0) : (int)($p['lic']['p180'] ?? 0);
        if ($price <= 0) { set_step($uid, ''); send($chat, "⚠️ Bu tarif narxi hali belgilanmagan.", main_kb($uid)); exit; }
        set_step($uid, '');
        $title = $p['name'] . " — " . ($days == 365 ? "1 yil" : "6 oy") . " litsenziya";
        pc_start_license_payment($chat, $uid, $price, (int)$pid, $title, (int)$days, $dev, pc_secret_of($p));
        exit;
    }
    if (strpos($step, 'pinrst:') === 0) {
        $pid = (int)substr($step, 7);
        $dev = pc_norm_device($text);
        if (!$dev) { send($chat, "❗ Kod noto'g'ri. Masalan: <code>7F3A-91BC</code>"); exit; }
        $p = products()['items'][$pid] ?? null;
        set_step($uid, '');
        $key = pc_reset_key($dev, $p ? pc_secret_of($p) : PC_SECRET);
        send($chat, "♻️ <b>PIN reset kaliti</b>\n\n📱 Qurilma: <code>" . esc($dev) . "</code>\n🔐 Reset kaliti: <code>$key</code>\n\nIlovada «PIN esimdan chiqdi» → bu kalitni kiriting → yangi PIN o'rnating.", main_kb($uid));
        exit;
    }
    if (strpos($step, 'licprice:') === 0) {
        if (!is_admin($uid)) { set_step($uid, ''); return; }
        @list(, $pid, $days) = explode(':', $step);
        $val = (int)preg_replace('/\D/', '', $text);
        $P = products();
        if (isset($P['items'][(int)$pid])) {
            if (!isset($P['items'][(int)$pid]['lic'])) $P['items'][(int)$pid]['lic'] = [];
            $P['items'][(int)$pid]['lic'][$days == 365 ? 'p365' : 'p180'] = $val;
            db_save('products', $P);
        }
        set_step($uid, '');
        send($chat, "✅ Narx saqlandi.", admin_kb());
        exit;
    }
    return;
}
