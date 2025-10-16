package main

import "core:fmt"
import "core:strings"
import "core:reflect"
import rl "vendor:raylib"

GUI_BUTTON_PERK_SIZE :: 50
DEFAULT_FONT_SIZE :: 15
DEFAULT_FONT_SPACING :: 2

FontSize :: u8

UILayout :: struct {
    bound : UIBound,
    at : UIVec2,
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

UIVec2 :: struct {
    x : i32,
    y : i32,
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
		case .BOTTOM_LEFT:		return { bound.x, -bound.y-bound.height, bound.width, bound.height }
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

/* Anchoring */

_gui_update :: proc() {

}

panelBounds := rl.Rectangle{ 0, 0, 300, 300 }
contentRect := rl.Rectangle{ 0, 0, 280, 800 }
scroll : rl.Vector2
view : rl.Rectangle

// converts rect in virtual space to screen space
_ui_rect :: proc (bound : UIBound) -> rl.Rectangle {
    return {f32(bound.x), f32(bound.y), f32(bound.width), f32(bound.height)}
}

_ui_draw_text :: proc (pos : UIVec2, text : cstring, color : rl.Color = rl.DARKGRAY, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING) {
    rl.DrawText(text, pos.x, pos.y, i32(font_size), color)
}

_ui_button :: proc(bound: UIBound, text: cstring, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING) -> bool {
    pressed := rl.GuiButton(_ui_rect(bound), nil)
    _ui_draw_text({bound.x,bound.y}, text, font_size = font_size, font_spacing = font_spacing)
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
        x=pos.x+anchor.x,
        y=pos.y+anchor.y,
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
    return {bound = bound, at = {bound.x, bound.y}}
}

_ui_content_from_panel :: proc(panel: UIBound, padding: UIPadding = {}) -> (content: UIBound) {
    TITLE_OFFSET :: 20
    content.x = panel.x + padding.left
    content.y = panel.y + TITLE_OFFSET + padding.top
    content.width = panel.width - padding.left - padding.right
    content.height = panel.height - padding.top - padding.bottom - TITLE_OFFSET
    return
}

_gui_draw_perk_button :: proc(perk: PerkID) { 

}

_color_to_i32 :: proc(color: rl.Color) -> i32 {
    return transmute(i32)(u32(color.r) << 24 | u32(color.g) << 16 | u32(color.b) << 8 | u32(color.a) << 0)
}

_gui_draw_perks_panel :: proc() {
    i : i32 = 0
    for perk, perk_val in DB.perk_data {
        state_color : i32 
        switch perk_val.buyable_state {
            case .UnmetRequirements:
                state_color = _color_to_i32(rl.RED)
            case .Buyable:
                state_color = _color_to_i32(rl.GREEN)
            case .Owned:
                state_color = _color_to_i32(rl.SKYBLUE)
            case .Free:
                state_color = _color_to_i32(rl.YELLOW)
        }
        rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), state_color)
        perk_name, _ := reflect.enum_name_from_value(perk)
        if _ui_button({0, i*GUI_BUTTON_PERK_SIZE, GUI_BUTTON_PERK_SIZE, GUI_BUTTON_PERK_SIZE}, strings.clone_to_cstring(perk_name, context.temp_allocator)) {
            buy_perk(perk)
        }
        // rl.GuiButton({0,i*GUI_BUTTON_PERK_SIZE, GUI_BUTTON_PERK_SIZE, GUI_BUTTON_PERK_SIZE}, strings.clone_to_cstring(perk_name, context.temp_allocator))
        i += 1
    }
}

_gui_draw_unit_panel :: proc () {
    unit_panel_bound := UIBound{rl.GetScreenWidth() * 80 / 100, 0, rl.GetScreenWidth() * 20 / 100, rl.GetScreenHeight()}
    unit_content_bound := _ui_content_from_panel(unit_panel_bound)
    rl.GuiPanel(_ui_rect(unit_panel_bound), "Unit")
    level_button_bound := _ui_anchor({unit_content_bound.x, unit_content_bound.y}, {0,0,unit_content_bound.width,200})

    level_button_label := strings.clone_to_cstring(fmt.tprint("Level:", DB.unit_level), context.temp_allocator)
    if _ui_button(level_button_bound, nil) do level_up()
    _ui_draw_text_aligned_in_bound(level_button_bound, level_button_label, .Center, font_size = 30)

    points_left_label := strings.clone_to_cstring(fmt.tprint(DB.unused_points, "\npoints left", sep=""), context.temp_allocator)
    points_left_bound := _ui_anchor({unit_content_bound.x, unit_content_bound.y},{0,200,unit_content_bound.width,200})
    _ui_draw_text_aligned_in_bound(points_left_bound, points_left_label, .Center, font_size = 30)
}

_gui_draw_main_skills_panel :: proc() {
    main_skills_panel_bound := UIBound{rl.GetScreenWidth() * 25 / 100, 0, rl.GetScreenWidth() * 55 / 100, rl.GetScreenHeight() * 50 / 100}
    main_skills_content_bound := _ui_content_from_panel(main_skills_panel_bound, {50, 50, 50, 50})
    SEPARATOR :: 50
    SKILL_BUTTON_WIDTH := (main_skills_content_bound.width - (MAIN_SKILLS_AMOUNT-1)*SEPARATOR)/MAIN_SKILLS_AMOUNT
    layout := _ui_layout(main_skills_content_bound)
    rl.GuiPanel(_ui_rect(main_skills_panel_bound), "Main Skills")
    
    content_bottom_left := _ui_anchored_pos(.BOTTOM_LEFT, main_skills_content_bound)
    // _ui_button(main_skills_panel_bound, nil)
    for skill_id, slot in DB.owned_main_skills {
        skill_id_data := DB.skill_id_data[skill_id]
        skill_level := DB.owned_skills[skill_id]
        next_skill := LeveledSkill{skill_id, skill_level+1}

        buyable_data := DB.buyable_data[next_skill]
        slot_cap := DB.player_states[DB.unit_level].main_skill_caps[slot]
        
        button_bound := _ui_anchor(content_bottom_left, _ui_bound_from_anchor(.BOTTOM_LEFT,{(SKILL_BUTTON_WIDTH+SEPARATOR)*i32(slot), 0, SKILL_BUTTON_WIDTH, main_skills_content_bound.height}))
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
        owned_bound := _ui_anchor(content_bottom_left, _ui_bound_from_anchor(.BOTTOM_LEFT,{(SKILL_BUTTON_WIDTH+SEPARATOR)*i32(slot), 0, button_bound.width, button_bound.height/MAX_SKILL_LEVEL*i32(skill_level)}))
        
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
        cap_bound := _ui_anchor(content_bottom_left, _ui_bound_from_anchor(.BOTTOM_LEFT,{(SKILL_BUTTON_WIDTH+SEPARATOR)*i32(slot), 0, button_bound.width, button_bound.height/MAX_SKILL_LEVEL*i32(slot_cap)}))
        rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), _color_to_i32(rl.MAGENTA))
        _ui_button(cap_bound, nil)

        if skill_level == 0 {
            rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), _color_to_i32(rl.GRAY))
            _ui_button(button_bound, nil)
            _ui_draw_text_aligned_in_bound(button_bound, button_label_c_string, .Center)
        }
        else {
            rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), _color_to_i32(state_color))
            _ui_button(owned_bound, nil)
            _ui_draw_text_aligned_in_bound(owned_bound, button_label_c_string, .Center)
        }



        rl.GuiUnlock()
        rl.GuiLoadStyleDefault()
    }
}

_gui_draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground(rl.WHITE)
    {
        _gui_draw_perks_panel()
        _gui_draw_main_skills_panel()
        _gui_draw_unit_panel()
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
