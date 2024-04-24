Hidppgui
========

A simple, small companion helper app for using Logitech mouse on macOS
without installing the [Logitech apps](https://www.logitech.com/en-us/software/options.html) or drivers.

This application provides a simple menu bar interface to configure
DPI sensitivity, wheel scrolling behaviors, battery status indicator
that makes Logitech mouse work as like Apple mouse, which would help to
switch from Apple mouse to the Logitech mouse without any hassle.


Usage
-----

Download the latest pre-build application binary from [Releases](https://github.com/niw/Hidppgui/releases)
page or build it from the source code by following instruction.

Note that the pre-build application binary is only ad-hoc signed.
Therefore, you need to click Open Anyway to execute it on
Security & Privacy settings in System Settings.

The application is also need your approval to Accessibility access.
Follow the instruction appears on the dialog.


Build
-----

You need to use the latest macOS and Xcode to build the app.
Open `Applications/Hidppgui.xcodeproj` and build `Hidppgui`
scheme for running.

If you have used another binary, next time when you launch the new binary,
it will shows an dialog to approve Accessibility access again.
However, often it doesn't work as expected for the new binary.
Therefore, use following command before launching the new binary to reset
Accessibility access.

```bash
tccutil reset Accessibility at.niw.Hidppgui
```
