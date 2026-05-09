#include "lvgl.h"

void lvgl9_preview_ui_create(void)
{
    lv_obj_t *scr = lv_scr_act();
    lv_obj_set_style_bg_color(scr, lv_color_hex(0x101820), 0);
    lv_obj_set_style_bg_opa(scr, LV_OPA_COVER, 0);

    lv_obj_t *title = lv_label_create(scr);
    lv_label_set_text(title, "LVGL9 Preview Demo");
    lv_obj_set_style_text_color(title, lv_color_hex(0xFFFFFF), 0);
    lv_obj_set_style_text_font(title, &lv_font_montserrat_14, 0);
    lv_obj_align(title, LV_ALIGN_TOP_MID, 0, 12);

    lv_obj_t *sub = lv_label_create(scr);
    lv_label_set_text(sub, "imx6ull-pro framebuffer");
    lv_obj_set_style_text_color(sub, lv_color_hex(0x99D9EA), 0);
    lv_obj_align_to(sub, title, LV_ALIGN_OUT_BOTTOM_MID, 0, 6);

    lv_obj_t *bar = lv_bar_create(scr);
    lv_obj_set_size(bar, 280, 20);
    lv_obj_align(bar, LV_ALIGN_BOTTOM_MID, 0, -26);
    lv_bar_set_range(bar, 0, 100);
    lv_bar_set_value(bar, 72, LV_ANIM_ON);

    lv_obj_t *status = lv_label_create(scr);
    lv_label_set_text(status, "Boot auto-start: OK");
    lv_obj_set_style_text_color(status, lv_color_hex(0xB5E61D), 0);
    lv_obj_align_to(status, bar, LV_ALIGN_OUT_TOP_MID, 0, -12);

    lv_obj_t *btn = lv_btn_create(scr);
    lv_obj_set_size(btn, 120, 44);
    lv_obj_align(btn, LV_ALIGN_CENTER, 0, 18);

    lv_obj_t *btn_label = lv_label_create(btn);
    lv_label_set_text(btn_label, "Touch Test");
    lv_obj_center(btn_label);
}
