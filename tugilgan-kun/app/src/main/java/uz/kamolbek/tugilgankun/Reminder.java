package uz.kamolbek.tugilgankun;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Locale;

/**
 * Har kuni ertalab soat 9:00 atrofida ishga tushadi va bugungi yoki ertangi
 * tugʻilgan kunlar hamda bayramlar haqida bildirishnoma chiqaradi.
 * Hodisalar roʻyxatini sahifa (index.html) tayyorlab beradi.
 */
public class Reminder extends BroadcastReceiver {

    static final String PREF = "tk";
    static final String KEY_EVENTS = "events";
    static final String KEY_LAST = "last";
    static final String CHANNEL = "tk_eslatma";
    static final String ACTION_CHECK = "uz.kamolbek.tugilgankun.CHECK";

    @Override
    public void onReceive(Context c, Intent i) {
        String a = i.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(a) || Intent.ACTION_MY_PACKAGE_REPLACED.equals(a)) {
            if (c.getSharedPreferences(PREF, 0).getBoolean("on", false)) schedule(c);
            return;
        }
        check(c);
    }

    private static PendingIntent alarmIntent(Context c) {
        Intent i = new Intent(c, Reminder.class).setAction(ACTION_CHECK);
        return PendingIntent.getBroadcast(c, 1, i,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }

    static void schedule(Context c) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.HOUR_OF_DAY, 9);
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        if (cal.getTimeInMillis() <= System.currentTimeMillis()) cal.add(Calendar.DAY_OF_MONTH, 1);
        am.setInexactRepeating(AlarmManager.RTC_WAKEUP, cal.getTimeInMillis(),
                AlarmManager.INTERVAL_DAY, alarmIntent(c));
    }

    static void cancel(Context c) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am != null) am.cancel(alarmIntent(c));
    }

    private static String day(Calendar cal) {
        return new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.getTime());
    }

    static void check(Context c) {
        SharedPreferences p = c.getSharedPreferences(PREF, 0);
        Calendar cal = Calendar.getInstance();
        String today = day(cal);
        if (today.equals(p.getString(KEY_LAST, ""))) return; // bir kunda bir marta
        p.edit().putString(KEY_LAST, today).apply();
        cal.add(Calendar.DAY_OF_MONTH, 1);
        String tomorrow = day(cal);

        try {
            JSONArray arr = new JSONArray(p.getString(KEY_EVENTS, "[]"));
            int id = 100;
            for (int k = 0; k < arr.length(); k++) {
                JSONObject o = arr.getJSONObject(k);
                String d = o.optString("d");
                String t = o.optString("t");
                String x = o.optString("x");
                if (today.equals(d)) notify(c, id++, "Bugun: " + t, x);
                else if (tomorrow.equals(d)) notify(c, id++, "Ertaga: " + t, x);
            }
        } catch (Exception ignored) {
        }
    }

    private static void notify(Context c, int id, String title, String text) {
        NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;
        nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Eslatmalar",
                NotificationManager.IMPORTANCE_DEFAULT));
        PendingIntent open = PendingIntent.getActivity(c, 0,
                new Intent(c, MainActivity.class).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_IMMUTABLE);
        Notification n = new Notification.Builder(c, CHANNEL)
                .setSmallIcon(R.drawable.ic_notif)
                .setColor(0xFF1C3D96)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(new Notification.BigTextStyle().bigText(text))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build();
        nm.notify(id, n);
    }
}
