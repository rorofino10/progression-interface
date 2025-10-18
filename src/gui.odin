#+feature dynamic-literals
package main

import "core:fmt"
import "core:strings"
import "core:reflect"
import rl "vendor:raylib"

DEFAULT_FONT_SIZE :: 15
DEFAULT_FONT_SPACING :: 2
DEFAULT_LINE_SPACING :: 15

VRES_HEIGHT :: 1080
VRES_WIDTH :: 1920

FontSize :: u8

UILayout :: struct {
    bound : UIBound,
    at : UIVec2,
}

UIPanel :: struct {
    name : cstring,
    draw : proc(UIBound),
}

UILayoutDirection :: enum {
    VERTICAL,
    HORIZONTAL,
}

UIPanelLayout :: struct {
    distribution : [dynamic]i32,
    panels : [dynamic]UIPanel,
    direction : UILayoutDirection,
}

UIBound :: struct {
    x : i32,
    y : i32,
    width : i32,
    height : i32,
}

UISize :: struct {
    width : i32,
    height : i32,
}

UIVec2 :: [2]i32
UIRatio :: struct {
    w : f32,
    h : f32,
}

UIAlign :: enum {
    Left,
    Center,
    Right,
    CenterBottom,
    CenterTop,
}

UIPadding :: struct {
    left : i32,
    right : i32,
    top : i32,
    bottom : i32,
}

/* Anchoring */

Anchor :: enum {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	CENTER_LEFT,
	CENTER,
	CENTER_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
}
_ui_anchored_bound :: proc( anchor: Anchor, bound: UIBound ) -> UIBound {
	switch anchor {
		case .TOP_LEFT:			return { bound.x+0,						    bound.y+0, bound.width, bound.height }
		case .TOP_CENTER:		return { bound.x+(bound.width - bound.x)/2,	bound.y+0, bound.width, bound.height }
		case .TOP_RIGHT:		return { bound.x+(bound.width - bound.x),	bound.y+0, bound.width, bound.height }
		case .CENTER_LEFT:		return { bound.x+0,						    bound.y+(bound.height- bound.y)/2, bound.width, bound.height }
		case .CENTER:			return { bound.x+(bound.width - bound.x)/2,	bound.y+(bound.height- bound.y)/2, bound.width, bound.height }
		case .CENTER_RIGHT:		return { bound.x+(bound.width - bound.x),	bound.y+(bound.height- bound.y)/2, bound.width, bound.height }
		case .BOTTOM_LEFT:		return { bound.x+0,						    bound.y+(bound.height- bound.y), bound.width, bound.height }
		case .BOTTOM_CENTER:	return { bound.x+(bound.width - bound.x)/2,	bound.y+(bound.height- bound.y), bound.width, bound.height }
		case .BOTTOM_RIGHT:		return { bound.x+(bound.width - bound.x),	bound.y+(bound.height- bound.y), bound.width, bound.height }
	}
	return {}
}
_ui_bound_from_anchor :: proc( anchor: Anchor, bound: UIBound ) -> UIBound {
	switch anchor {
		case .TOP_LEFT:			return {  }
		case .TOP_CENTER:		return {  }
		case .TOP_RIGHT:		return {  }
		case .CENTER_LEFT:		return {  }
		case .CENTER:			return {  }
		case .CENTER_RIGHT:		return {  }
		case .BOTTOM_LEFT:		return { bound.x, bound.y-bound.height, bound.width, bound.height }
		case .BOTTOM_CENTER:	return { }
		case .BOTTOM_RIGHT:		return { }
	}
	return {}
}

_ui_anchored_pos :: proc( anchor: Anchor, bound: UIBound ) -> UIVec2 {
	switch anchor {
		case .TOP_LEFT:			return { bound.x, bound.y}
		case .TOP_CENTER:		return { bound.x+bound.width/2, bound.y}
		case .TOP_RIGHT:		return { bound.x+bound.width, bound.y}
		case .CENTER_LEFT:		return { bound.x, bound.y+bound.height/2}
		case .CENTER:			return { bound.x+bound.width/2, bound.y+bound.height/2}
		case .CENTER_RIGHT:		return { bound.x+bound.width, bound.y+bound.height/2}
		case .BOTTOM_LEFT:		return { bound.x, bound.y+bound.height}
		case .BOTTOM_CENTER:	return { bound.x+bound.width/2, bound.y+bound.height}
		case .BOTTOM_RIGHT:		return { bound.x+bound.width, bound.y+bound.height}
	}
	return {}
}

/* Virtual Space -> Screen Space */

// returns ratio between virtual res and screen res
_ui_get_ratio :: proc () -> UIRatio {
    w := rl.GetRenderWidth()
    h := rl.GetRenderHeight()
    return {f32(w)/(VRES_WIDTH), f32(h)/(VRES_HEIGHT)}
}

// returns screen space size of font
_ui_get_font_size :: proc (virtual_size : FontSize) -> f32 {
    ratio := _ui_get_ratio()
    return f32(virtual_size)*ratio.w
}

// converts rect in virtual space to screen space
_ui_rect :: proc (bound : UIBound) -> rl.Rectangle {
    ratio := _ui_get_ratio()
    return {f32(bound.x)*ratio.w, f32(bound.y)*ratio.h, f32(bound.width)*ratio.w, f32(bound.height)*ratio.h}
}

/* Wrappers */

_ui_label :: proc(bound: UIBound, text: cstring, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING, line_spacing : f32 = DEFAULT_LINE_SPACING) {
    screen_font_size := _ui_get_font_size(font_size)

    rl.GuiSetStyle(.LABEL, i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL), _color_to_i32(rl.BLACK));
    rl.GuiSetStyle(.LABEL, i32(rl.GuiControlProperty.TEXT_ALIGNMENT), i32(rl.GuiTextAlignment.TEXT_ALIGN_CENTER));
    curr_style := rl.GuiGetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE))
    rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), i32(screen_font_size))
    rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_LINE_SPACING), i32(line_spacing))
    defer rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), curr_style)

    rl.GuiLabel(_ui_rect(bound), text)
    
}

_ui_button :: proc(bound: UIBound, text: cstring, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING, line_spacing : f32 = DEFAULT_LINE_SPACING) -> bool {
    pressed := rl.GuiButton(_ui_rect(bound), nil)
    // _ui_draw_text({bound.x,bound.y}, text, font_size = font_size, font_spacing = font_spacing)
    _ui_label(bound, text, font_size, font_spacing, line_spacing)

    return pressed
}

_ui_anchor :: proc(anchor : UIVec2, bound : UIBound) -> UIBound {
    return UIBound{
        x=bound.x+anchor.x,
        y=bound.y+anchor.y,
        width=bound.width,
        height=bound.height,
    }
}

_ui_anchor_pos :: proc(anchor : UIVec2, pos : UIVec2) -> UIVec2 {
    return UIVec2{
        pos.x+anchor.x,
        pos.y+anchor.y,
    }
}

_ui_center_div :: proc (container : UIBound, div_size : UISize, alignment : UIAlign, padding : UIPadding = {}) -> UIBound {
    switch alignment {
    case .Left:
        div_x := container.x + padding.left
        div_y := container.y + (container.height-div_size.height)/2
        return {div_x, div_y, div_size.width, div_size.height}
    case .Center:
        div_x := container.x + (container.width-div_size.width)/2
        div_y := container.y + (container.height-div_size.height)/2
        return {div_x, div_y, div_size.width, div_size.height}
    case .Right:
        div_x := container.x+container.width-div_size.width - padding.right
        div_y := container.y + (container.height-div_size.height)/2
        return {div_x, div_y, div_size.width, div_size.height}
    case .CenterBottom:
        div_x := container.x + (container.width-div_size.width)/2
        div_y := container.y + container.height - div_size.height - padding.bottom 
        return {div_x, div_y, div_size.width, div_size.height}
    case .CenterTop:
        div_x := container.x + (container.width-div_size.width)/2
        div_y := container.y + padding.top
        return {div_x, div_y, div_size.width, div_size.height}
    }
    return {}
}
_ui_draw_text_aligned_in_bound :: proc (container : UIBound, text : cstring, alignment : UIAlign, padding : UIPadding = {}, color : rl.Color = rl.DARKGRAY, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING) {
    text_size := rl.MeasureTextEx(rl.GuiGetFont(), text, f32(font_size), font_spacing)
    centered_div := _ui_center_div(container, {i32(text_size.x), i32(text_size.y)}, alignment, padding)
    rl.DrawTextEx(rl.GuiGetFont(), text, {f32(centered_div.x), f32(centered_div.y)}, f32(font_size), font_spacing, color)
}
_ui_draw_label_aligned_in_bound :: proc (container : UIBound, text : cstring, alignment : UIAlign, padding : UIPadding = {}, color : rl.Color = rl.DARKGRAY, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING) {
    text_size := rl.MeasureTextEx(rl.GuiGetFont(), text, f32(font_size), font_spacing)
    centered_div := _ui_center_div(container, {i32(text_size.x), i32(text_size.y)}, alignment, padding)
    rl.GuiLabel(_ui_rect(centered_div), text)
}

_ui_layout :: proc (bound : UIBound) -> UILayout {
    return {bound = bound, at = {0, 0}}
}

_ui_layout_advance :: proc(layout: ^UILayout, size: UISize, direction: UILayoutDirection) {
    switch direction {
        case .HORIZONTAL:
            layout.at.x += size.width
            if layout.at.x >= layout.bound.width {
                layout.at.x = 0
                layout.at.y += size.height
            }
        case .VERTICAL:
            layout.at.y += size.height
            if layout.at.y >= layout.bound.height {
                layout.at.y = 0
                layout.at.x += size.width
            }
    }
}

_ui_layout_button :: proc(layout : ^UILayout, size: UISize, text: cstring, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING) -> bool {
    // bound := _ui_row(layout, i32(font_size)*2, {UI_H_PADDING, UI_H_PADDING, UI_V_PADDING, UI_V_PADDING})
    pressed := _ui_button(_ui_anchor(layout.at,{0,0, size.width, size.height}), text, font_size, font_spacing)
    layout.at += {0, size.height}
    return pressed
}

_ui_draw_panel_layout :: proc(anchor: UIVec2, panel_layout: UIPanelLayout, span: i32) {
    for panel, panel_idx in panel_layout.panels {
        curr_anchor, next_anchor := panel_layout.distribution[panel_idx], panel_layout.distribution[panel_idx+1]
        panel_bound : UIBound 
        switch panel_layout.direction {
            case .HORIZONTAL: 
                panel_bound = _ui_anchor({curr_anchor * VRES_WIDTH / 100,0}, {0,0, (next_anchor-curr_anchor)*VRES_WIDTH / 100, span})
            case .VERTICAL:
                panel_bound = _ui_anchor({0,curr_anchor * VRES_HEIGHT / 100}, {0,0, span, (next_anchor-curr_anchor)*VRES_HEIGHT / 100})
        }
        panel_bound = _ui_anchor(anchor, panel_bound)
        rl.GuiPanel(_ui_rect(panel_bound), panel.name)
        panel.draw(panel_bound)
    }
}

_ui_content_from_panel :: proc(panel: UIBound, padding: UIPadding = {}, is_scrollable : bool = false) -> (content: UIBound) {
    TITLE_OFFSET :: 24
    SCROLL_BAR_WIDTH :: 14
    content.x = panel.x + padding.left
    content.y = panel.y + TITLE_OFFSET + padding.top
    content.width = panel.width - padding.left - padding.right - (is_scrollable ? SCROLL_BAR_WIDTH : 0)
    content.height = panel.height - padding.top - padding.bottom - TITLE_OFFSET
    return
}

_color_to_i32 :: proc(color: rl.Color) -> i32 {
    return transmute(i32)(u32(color.r) << 24 | u32(color.g) << 16 | u32(color.b) << 8 | u32(color.a) << 0)
}
perk_scroll : rl.Vector2
perk_view : rl.Rectangle
_gui_draw_perks_panel :: proc(panel_bound: UIBound) {
    PERKS_PER_ROW :: 2
    ROWS :: 5
    content_bound := _ui_content_from_panel(panel_bound)
    scroll_view := _ui_content_from_panel(panel_bound, {10,10,10,10}, true)
    PERK_BUTTON_SIZE := UISize{scroll_view.width/PERKS_PER_ROW, scroll_view.height/ROWS}

    perks_amount := i32(len(DB.perk_data))

    scroll_content_bound := _ui_content_from_panel({panel_bound.x, panel_bound.y, panel_bound.width, perks_amount/PERKS_PER_ROW*PERK_BUTTON_SIZE.height}, {10, 10, 10, 10}, true)

    rl.GuiScrollPanel(_ui_rect(panel_bound), "Perks", _ui_rect(scroll_content_bound), &perk_scroll, &perk_view)
    layout := _ui_layout(_ui_anchor({i32(perk_scroll.x), i32(perk_scroll.y)}, scroll_content_bound))

    // scroll_source := rl.Rectangle{ 0, -scroll_vector.y, scroll_image.width, scroll_view.height };
    // rl.DrawTexturePro(scroll_image, scroll_source, scroll, (Vector2){0}, 0, WHITE);    
    // content_bound := _ui_content_from_panel(panel_bound, {right=20})
    rl.BeginScissorMode(i32(perk_view.x), i32(perk_view.y), i32(perk_view.width), i32(perk_view.height));
    {
        
        for perk, perk_val in DB.perk_data {
            buyable_data := DB.buyable_data[perk]
            state_color : rl.Color
            switch perk_val.buyable_state {
                case .UnmetRequirements:
                    state_color = rl.RED
                case .Buyable:
                    state_color = rl.GREEN
                case .Owned:
                    state_color = rl.SKYBLUE
                case .Free:
                    state_color = rl.YELLOW
            }
            perk_name, _ := reflect.enum_name_from_value(perk)
            button_bound := _ui_anchor({layout.bound.x + layout.at.x, layout.bound.y + layout.at.y},{0, 0, PERK_BUTTON_SIZE.width, PERK_BUTTON_SIZE.height})
            _ui_layout_advance(&layout, PERK_BUTTON_SIZE, .HORIZONTAL)
            button_label : string
            if rl.CheckCollisionPointRec(rl.GetMousePosition(), _ui_rect(button_bound)) {
                button_label = fmt.tprint(perk_name, "\nCost: ", buyable_data.assigned_blocks_amount - buyable_data.bought_blocks_amount, sep = "") 
                if rl.IsMouseButtonPressed(.LEFT) do buy_perk(perk)
                if rl.IsMouseButtonPressed(.RIGHT) do refund_perk(perk)
            }
            else do button_label = fmt.tprint(perk_name)
            button_label_c_string := strings.clone_to_cstring(button_label, context.temp_allocator)

            rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), _color_to_i32(state_color))
            _ui_button(button_bound, button_label_c_string)
        }
    }
    rl.EndScissorMode()

}

_gui_draw_unit_panel :: proc (panel_bound: UIBound) {
    content_bound := _ui_content_from_panel(panel_bound)
    level_button_bound := _ui_anchor({content_bound.x, content_bound.y}, {0,0,content_bound.width,200})

    level_button_label := strings.clone_to_cstring(fmt.tprint("Level:", DB.unit_level), context.temp_allocator)
    if _ui_button(level_button_bound, level_button_label, 40, line_spacing = 40) do level_up()

    points_left_label := strings.clone_to_cstring(fmt.tprint(DB.unused_points, "\npoints left", sep=""), context.temp_allocator)
    points_left_bound := _ui_anchor({content_bound.x, content_bound.y+200},{0,0,content_bound.width,200})

    _ui_label(points_left_bound, points_left_label, font_size = 40, line_spacing = 40)
}

skills_panel_layout := UIPanelLayout{
    distribution = {0, 75, 100},
    panels = {{name="Main Skills",draw=_gui_draw_main_skills_panel}, {name="Extra Skills",draw=_gui_draw_extra_skills_panel}},
    direction = .VERTICAL,
}

_gui_draw_skills_panel :: proc(panel_bound: UIBound) {
    _ui_draw_panel_layout({panel_bound.x, panel_bound.y}, skills_panel_layout, panel_bound.width)
}


_gui_draw_extra_skills_panel :: proc(panel_bound: UIBound) {
}

_gui_draw_main_skills_panel :: proc(panel_bound: UIBound) {
    PAD := panel_bound.width*5/100
    SEPARATOR := i32(0)
    main_skills_content_bound := _ui_content_from_panel(panel_bound, {PAD, PAD, PAD, PAD})
    SKILL_BUTTON_WIDTH := (main_skills_content_bound.width - (MAIN_SKILLS_AMOUNT-1)*SEPARATOR)/MAIN_SKILLS_AMOUNT
    layout := _ui_layout(main_skills_content_bound)
    
    content_bottom_left := _ui_anchored_pos(.BOTTOM_LEFT, main_skills_content_bound)
    // _ui_button(main_skills_panel_bound, nil)
    for skill_id, slot in DB.owned_main_skills {
        skill_id_data := DB.skill_id_data[skill_id]
        skill_level := DB.owned_skills[skill_id]
        next_skill := LeveledSkill{skill_id, skill_level+1}

        buyable_data := DB.buyable_data[next_skill]
        slot_cap := DB.player_states[DB.unit_level].main_skill_caps[slot]
        
        button_bound := _ui_anchor(content_bottom_left+layout.at, _ui_bound_from_anchor(.BOTTOM_LEFT,{0, 0, SKILL_BUTTON_WIDTH, main_skills_content_bound.height}))
        state_color : rl.Color
        switch skill_id_data.raisable_state {
            case .NotEnoughPoints:
                state_color = rl.RED
            case .Raisable:
                state_color = rl.GREEN
            case .Capped:
                state_color = rl.SKYBLUE
            case .Free:
                state_color = rl.YELLOW
        }

        skill_name, _ := reflect.enum_name_from_value(skill_id)
        owned_bound := _ui_anchor(content_bottom_left+layout.at, _ui_bound_from_anchor(.BOTTOM_LEFT,{0, 0, button_bound.width, button_bound.height/MAX_SKILL_LEVEL*i32(skill_level)}))
        
        rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), 0x00000000)
        rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_FOCUSED), rl.GuiGetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL)));
        rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_PRESSED), rl.GuiGetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL)));

        _ui_button(button_bound, nil)

        button_label : string
        if rl.CheckCollisionPointRec(rl.GetMousePosition(), _ui_rect(button_bound)) {
            button_label = fmt.tprint(skill_name, " ", skill_level, "\nCost: ", buyable_data.assigned_blocks_amount - buyable_data.bought_blocks_amount, sep = "") 
            if rl.IsMouseButtonPressed(.RIGHT) do reduce_skill(skill_id)
            if rl.IsMouseButtonPressed(.LEFT) do raise_skill(skill_id)
        }
        else do button_label = fmt.tprint(skill_name, skill_level)
        button_label_c_string := strings.clone_to_cstring(button_label, context.temp_allocator)
        
        rl.GuiLock()
        cap_bound := _ui_anchor(content_bottom_left+layout.at, _ui_bound_from_anchor(.BOTTOM_LEFT,{0, 0, button_bound.width, button_bound.height/MAX_SKILL_LEVEL*i32(slot_cap)}))
        rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), _color_to_i32(rl.GRAY))
        _ui_button(cap_bound, nil)

        
        label_bound : UIBound
        if skill_level == 0 {label_bound = button_bound; state_color = rl.GRAY}
        else do label_bound = owned_bound
        rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), _color_to_i32(state_color))
        _ui_button(label_bound, button_label_c_string)

        rl.GuiUnlock()
        _ui_layout_advance(&layout, {SKILL_BUTTON_WIDTH+SEPARATOR, 0}, .HORIZONTAL)
        rl.GuiLoadStyleDefault()
    }
}

global_panel_layout := UIPanelLayout{
    distribution = {0, 25, 90, 100},
    panels = {{name="Perks",draw=_gui_draw_perks_panel}, {name="Skills",draw=_gui_draw_skills_panel}, {name="Unit",draw=_gui_draw_unit_panel}},
    direction = .HORIZONTAL,
}

_gui_draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground(rl.WHITE)

    {

        _ui_draw_panel_layout({0,0}, global_panel_layout, VRES_HEIGHT)

        // _gui_draw_perks_panel()
        // _gui_draw_main_skills_panel()
        // _gui_draw_unit_panel()
        // for perk, i in PerkID {
        //     rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), transmute(i32)u32(0xFF0000FF)); // Red background, full alpha
        //     perk_name, _ := reflect.enum_name_from_value(perk)
        //     rl.GuiButton(rl.Rectangle{0,f32(i * GUI_BUTTON_PERK_SIZE), GUI_BUTTON_PERK_SIZE, GUI_BUTTON_PERK_SIZE}, strings.clone_to_cstring(perk_name, context.temp_allocator))
        // }
        // rl.GuiScrollPanel(rl.Rectangle{0,0, 50, 200}, "Scroll", rl.Rectangle{0,0,0,f32(PerkID.COUNT) * f32(GUI_BUTTON_PERK_SIZE)}, &scroll, &view)

        // rl.GuiScrollPanel(panelBounds, nil, contentRect, &scroll, &view)

        // // Start scissor mode to limit drawing to the panel view
        // rl.BeginScissorMode(i32(view.x), i32(view.y), i32(view.width), i32(view.height))

        // // Draw 20 buttons inside the content area
        // for i := 0; i < 20; i += 1
        // {
        //     btnBounds := rl.Rectangle{ panelBounds.x + 10, panelBounds.y + 10 + f32(i) * 40 + scroll.y, 200, 30 }
        //     rl.GuiButton(btnBounds, rl.TextFormat("Button %02i", i + 1))
        // }

        // rl.EndScissorMode()
    }
    rl.EndDrawing()
}

_gui_update :: proc() {}

gui_run :: proc() {
    { // Init
        cfg := _cfg_default()
        rl.SetTraceLogLevel( .WARNING )
        rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT })
        rl.InitWindow( cfg.resolution_width, cfg.resolution_height, "App" )
        rl.SetTargetFPS( cfg.max_fps )
        if cfg.fullscreen do rl.ToggleFullscreen()
    }
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)
        _gui_update()
        _gui_draw()
    }

    if rl.IsWindowReady() do rl.CloseWindow()
}


Config :: struct {
    fullscreen : bool,
    resolution_width : i32,
    resolution_height : i32,
    max_fps : i32,
}


_cfg_default :: proc() -> Config {
    cfg := Config{
        fullscreen = false,
        resolution_width = 1920,
        resolution_height = 1080,
        max_fps = 60,
    }
    return cfg
}
