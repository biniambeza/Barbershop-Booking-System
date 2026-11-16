#import "GeneratedPluginRegistrant.h"

// FLTFirebaseMessagingPlugin is called from AppDelegate.swift. CocoaPods
// exposes it as <firebase_messaging/...>; Swift Package Manager (the Flutter
// default) only through the plugin's Clang module, so try both.
#if __has_include(<firebase_messaging/FLTFirebaseMessagingPlugin.h>)
#import <firebase_messaging/FLTFirebaseMessagingPlugin.h>
#else
@import firebase_messaging;
#endif
