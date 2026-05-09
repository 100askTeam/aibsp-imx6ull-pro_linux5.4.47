#include <signal.h>
#include <stdio.h>
#include <unistd.h>

#include "lvgl.h"

void lvgl9_preview_ui_create(void);
lv_display_t *lv_linux_fbdev_create(void);
void lv_linux_fbdev_set_file(lv_display_t *disp, const char *file);
lv_indev_t *lv_evdev_create(lv_indev_type_t indev_type, const char *dev_path);

static volatile sig_atomic_t g_stop;

static void handle_stop(int sig)
{
    (void)sig;
    g_stop = 1;
}

int main(int argc, char **argv)
{
    const char *fbdev = "/dev/fb0";
    const char *evdev = "/dev/input/event0";

    if (argc > 1) {
        fbdev = argv[1];
    }
    if (argc > 2) {
        evdev = argv[2];
    }

    signal(SIGINT, handle_stop);
    signal(SIGTERM, handle_stop);

    lv_init();

    lv_display_t *disp = lv_linux_fbdev_create();
    if (!disp) {
        fprintf(stderr, "lvgl9-demo: failed to create fb display\n");
        return 1;
    }
    lv_linux_fbdev_set_file(disp, fbdev);

    lv_indev_t *touch = lv_evdev_create(LV_INDEV_TYPE_POINTER, evdev);
    if (touch) {
        lv_indev_set_display(touch, disp);
    } else {
        fprintf(stderr, "lvgl9-demo: no evdev pointer on %s, continue\n", evdev);
    }

    lvgl9_preview_ui_create();

    while (!g_stop) {
        lv_timer_handler();
        usleep(5000);
    }

    return 0;
}
