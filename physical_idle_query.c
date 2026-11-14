// Query CoreGraphics for HID-system (hardware) input idle time.
// This does not capture or store keystrokes, mouse positions, or event details.
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static double idle_for(CGEventSourceStateID state) {
    return CGEventSourceSecondsSinceLastEventType(state, kCGAnyInputEventType);
}

int main(int argc, char **argv) {
    double hid = idle_for(kCGEventSourceStateHIDSystemState);
    if (!isfinite(hid) || hid < 0 || hid > 315360000.0) {
        fputs("HID idle time unavailable\n", stderr);
        return 2;
    }
    if (argc > 1 && strcmp(argv[1], "--both") == 0) {
        double combined = idle_for(kCGEventSourceStateCombinedSessionState);
        if (!isfinite(combined) || combined < 0) combined = -1.0;
        printf("HID_SECONDS=%.3f\nSESSION_SECONDS=%.3f\n", hid, combined);
    } else {
        printf("%.3f\n", hid);
    }
    return 0;
}
