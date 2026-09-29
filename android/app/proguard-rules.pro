# The text recognition plugin refers to every ML Kit script recogniser, but
# only the Latin one is bundled. Without these, R8 stops the release build
# on the missing Chinese, Devanagari, Japanese and Korean options classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
