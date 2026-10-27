# Mobile controls and screen fit

The owner prioritizes phone players. Android's accessibility guidance recommends
at least 48 × 48 dp interactive targets; this is guidance for Android apps, used
here as a conservative CSS-pixel design target for browser controls rather than
a guarantee about every phone's physical sizing. The camera panel previously
used 42 px buttons and a 32 px range input. They now provide 48 px hit heights.
[Android guidance](https://developer.android.com/guide/topics/ui/accessibility/apps)

CSS safe-area inset variables describe the usable rectangle around cutouts and
screen edges. The HUD, board and overlay account for left and right as well as
top and bottom insets, particularly for landscape phones. Actual device
cutouts, gesture navigation, input feel and rendering performance remain to be
checked on a real Android phone; emulation does not establish these.
[MDN: env()](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/env),
[Chrome: device simulation](https://developer.chrome.com/docs/devtools/device-mode).
