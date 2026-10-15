# Os plugins fornecem suas consumer rules; manter as interfaces JavaScript
# usadas pelo WebView e os métodos chamados via JNI.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
