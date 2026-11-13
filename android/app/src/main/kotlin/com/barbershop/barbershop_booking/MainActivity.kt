package com.barbershop.barbershop_booking

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createBookingsChannel()
    }

    /** The channel the notifications Cloud Functions send booking pushes to. */
    private fun createBookingsChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "bookings",
            "Bookings",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Booking confirmations, changes and reminders"
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }
}
