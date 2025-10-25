#+feature dynamic-literals
package main

import "core:slice"
import "core:fmt"
import "core:strings"
import "core:reflect"
import rl "vendor:raylib"

DEFAULT_FONT_SIZE :: 15
DEFAULT_FONT_SPACING :: 2
DEFAULT_LINE_SPACING :: DEFAULT_FONT_SIZE+5

VRES_HEIGHT :: 720
VRES_WIDTH :: 1280

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
    w := rl.GetScreenWidth()
    h := rl.GetScreenHeight()
    return {f32(w)/(VRES_WIDTH), f32(h)/(VRES_HEIGHT)}
}
_ui_get_ratio_from_screen_to_virtual :: proc () -> UIRatio {
    return {VRES_WIDTH/f32(rl.GetScreenWidth()), VRES_HEIGHT/f32(rl.GetScreenHeight())}
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

_ui_bound :: proc(rect : rl.Rectangle) -> UIBound {
    return {i32(rect.x), i32(rect.y), i32(rect.width), i32(rect.height)}
}

/* Wrappers */

_ui_label :: proc(bound: UIBound, text: cstring, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING, line_spacing : f32 = DEFAULT_LINE_SPACING) {
    screen_font_size := _ui_get_font_size(font_size)

    rl.GuiSetStyle(.LABEL, i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL), _color_to_i32(rl.BLACK));
    rl.GuiSetStyle(.LABEL, i32(rl.GuiControlProperty.TEXT_ALIGNMENT), i32(rl.GuiTextAlignment.TEXT_ALIGN_CENTER));
    curr_style := rl.GuiGetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE))
    defer rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), curr_style)
    rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), i32(screen_font_size))
    rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_LINE_SPACING), i32(line_spacing))

    rl.GuiLabel(_ui_rect(bound), text)
    
}

_ui_button_with_color :: proc(bound: UIBound, text: cstring = nil, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING, line_spacing : f32 = DEFAULT_LINE_SPACING, padding : UIPadding = {}, color : rl.Color) -> bool {
    prev_color := rl.GuiGetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL))
    defer rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), prev_color) 
    rl.GuiSetStyle(rl.GuiControl.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), _color_to_i32(color))
    return _ui_button(bound, text, font_size, font_spacing, line_spacing, padding)
}

_ui_button :: proc(bound: UIBound, text: cstring = nil, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING, line_spacing : f32 = DEFAULT_LINE_SPACING, padding : UIPadding = {}) -> bool {
    padded_bound := UIBound{bound.x+padding.left, bound.y+padding.top, bound.width-padding.left-padding.right, bound.height-padding.top-padding.bottom}
    pressed := rl.GuiButton(_ui_rect(padded_bound), nil)
    _ui_label(padded_bound, text, font_size, font_spacing, line_spacing)

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
            remaining := layout.bound.width - layout.at.x 
            if size.width > remaining {
                layout.at.x = 0
                layout.at.y += size.height
            }
        case .VERTICAL:
            layout.at.y += size.height
            remaining := layout.bound.height - layout.at.y 
            if size.height > remaining {
                layout.at.y = 0
                layout.at.x += size.width
            }
    }
}

_ui_layout_button :: proc(layout : ^UILayout, size: UISize, text: cstring, font_size : FontSize = DEFAULT_FONT_SIZE, font_spacing : f32 = DEFAULT_FONT_SPACING) -> bool {
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
    TITLE_OFFSET :: 17
    SCROLL_BAR_WIDTH :: 10
    content.x = panel.x + padding.left
    content.y = panel.y + TITLE_OFFSET + padding.top
    content.width = panel.width - padding.left - padding.right - (is_scrollable ? SCROLL_BAR_WIDTH : 0)
    content.height = panel.height - padding.top - padding.bottom - TITLE_OFFSET
    return
}

_color_to_i32 :: proc(color: rl.Color) -> i32 {
    return transmute(i32)(u32(color.r) << 24 | u32(color.g) << 16 | u32(color.b) << 8 | u32(color.a) << 0)
}

extra_skills_scroll : rl.Vector2
extra_skills_view : rl.Rectangle

_gui_draw_extra_skills_panel :: proc(panel_bound: UIBound) {
    ratio := _ui_get_ratio_from_screen_to_virtual()

    SKILLS_PER_ROW :: 5
    ROWS :: 2
    scroll_view := _ui_content_from_panel(panel_bound, {}, true)
    SKILL_BUTTON_HEIGHT := scroll_view.height/ROWS
    extra_skills_amount := i32(len(DB.owned_extra_skills))

    scroll_content_bound_height := (extra_skills_amount + SKILLS_PER_ROW - 1)/SKILLS_PER_ROW*SKILL_BUTTON_HEIGHT
    scroll_content_bound := _ui_content_from_panel({panel_bound.x, panel_bound.y, panel_bound.width, scroll_content_bound_height}, {}, scroll_view.height < scroll_content_bound_height)

    SKILL_BUTTON_SIZE := UISize{scroll_content_bound.width/SKILLS_PER_ROW, SKILL_BUTTON_HEIGHT}
    
    rl.GuiScrollPanel(_ui_rect(panel_bound), "Extra Skills", _ui_rect(scroll_content_bound), &extra_skills_scroll, &extra_skills_view)
    
    view_bound := _ui_bound(extra_skills_view)
    layout := _ui_layout(scroll_content_bound)

    rl.BeginScissorMode(view_bound.x, view_bound.y, view_bound.width, view_bound.height)
    {
        // TODO: Make this not... Bad
        for skill_id, slot in DB.owned_extra_skills {
            skill_id_data := DB.skill_id_data[skill_id]
            skill_level := DB.owned_skills[skill_id]
            next_skill := LeveledSkill{skill_id, skill_level+1}

            buyable_data := DB.buyable_data[next_skill]
            slot_cap := DB.player_states[DB.unit_level].extra_skill_cap

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
            button_bound := _ui_anchor({layout.bound.x + layout.at.x + i32(extra_skills_scroll.x * ratio.w), layout.bound.y + layout.at.y + i32(extra_skills_scroll.y * ratio.h)},{0, 0, SKILL_BUTTON_SIZE.width, SKILL_BUTTON_SIZE.height})
            _ui_layout_advance(&layout, SKILL_BUTTON_SIZE, .HORIZONTAL)

            button_label : cstring
            if skill_level == 0 {
                button_label = fmt.ctprint("Unlock\n",skill_name, sep = "") 
            }
            else {
                button_label = fmt.ctprint(skill_name, skill_level) 
            } 

            if !_is_message_active() && !_is_message_active() && rl.CheckCollisionPointRec(rl.GetMousePosition(), _ui_rect(button_bound)) {
                switch skill_id_data.raisable_state {
                    case .NotEnoughPoints, .Raisable, .Capped:
                        button_label = fmt.ctprint(button_label, "\n", buyable_data.assigned_blocks_amount - buyable_data.bought_blocks_amount, " to raise", sep = "") 
                    case .Free:
                        button_label = fmt.ctprint(button_label, "FREE to raise", sep = "\n") 
                }
                if rl.IsKeyPressed(.B) do print_buyable_blocks(next_skill)
                if rl.IsMouseButtonPressed(.RIGHT) {
                    refund, err := reduce_skill(skill_id)
                    if err != nil do _gui_blinker_start(LeveledSkill{skill_id, skill_level},err)
                }
                if rl.IsMouseButtonPressed(.LEFT) do raise_skill(skill_id)
            }
            _ui_button_with_color(button_bound, button_label, padding = {}, color = state_color)
        }
    }
    rl.EndScissorMode()
}
perk_scroll : rl.Vector2
perk_view : rl.Rectangle
_gui_draw_perks_panel :: proc(panel_bound: UIBound) {
    ratio := _ui_get_ratio_from_screen_to_virtual()
    PERKS_PER_ROW :: 2
    ROWS :: 5
    scroll_view := _ui_content_from_panel(panel_bound, {}, true)
    PERK_BUTTON_HEIGHT := scroll_view.height/ROWS

    perks_amount := i32(len(DB.perk_data))
    scroll_content_bound_height := (perks_amount + PERKS_PER_ROW - 1)/PERKS_PER_ROW*PERK_BUTTON_HEIGHT
    scroll_content_bound := _ui_content_from_panel({panel_bound.x, panel_bound.y, panel_bound.width, scroll_content_bound_height}, {}, scroll_view.height < scroll_content_bound_height)

    PERK_BUTTON_SIZE := UISize{scroll_content_bound.width/PERKS_PER_ROW, PERK_BUTTON_HEIGHT}

    rl.GuiScrollPanel(_ui_rect(panel_bound), "Perks", _ui_rect(scroll_content_bound), &perk_scroll, &perk_view)

    view_bound := _ui_bound(perk_view)
    layout := _ui_layout(scroll_content_bound)

    rl.BeginScissorMode(view_bound.x, view_bound.y, view_bound.width, view_bound.height);
    {
        // TODO: Make this not... Bad
        for perk, perk_val in DB.perk_data do if perk_val.buyable_state != .UnmetRequirements {
            buyable_data := DB.buyable_data[perk]
            state_color : rl.Color
            #partial switch perk_val.buyable_state {
                case .Buyable:
                    state_color = rl.GREEN
                case .Owned:
                    state_color = rl.SKYBLUE
                case .Free:
                    state_color = rl.YELLOW
            }
            if _should_blink_perk(perk) do state_color = rl.MAGENTA

            button_bound := _ui_anchor({layout.bound.x + layout.at.x + i32(perk_scroll.x * ratio.w) , layout.bound.y + layout.at.y + i32(perk_scroll.y * ratio.h)},{0, 0, PERK_BUTTON_SIZE.width, PERK_BUTTON_SIZE.height})
            _ui_layout_advance(&layout, PERK_BUTTON_SIZE, .HORIZONTAL)

            button_label : string
            if !_is_message_active() && rl.CheckCollisionPointRec(rl.GetMousePosition(), _ui_rect(button_bound)) {
                #partial switch perk_val.buyable_state {
                    case .Buyable:
                        button_label = fmt.tprint(perk_val.display, "\nCost: ", buyable_data.assigned_blocks_amount - buyable_data.bought_blocks_amount, sep = "") 
                    case .Owned:
                        state_color = rl.SKYBLUE
                        button_label = fmt.tprint(perk_val.display, "\nRefund", sep = "") 
                    case .Free:
                        state_color = rl.YELLOW
                        button_label = fmt.tprint(perk_val.display, "\nFREE", sep = "") 
                }
                if rl.IsMouseButtonPressed(.LEFT) do buy_perk(perk)
                if rl.IsMouseButtonPressed(.RIGHT) {
                    refund, err := refund_perk(perk)
                    if err != nil {
                        fmt.println(err)
                        _gui_blinker_start(perk, err)
                    }
                }
            }
            else do button_label = fmt.tprint(perk_val.display)
            button_label_c_string := strings.clone_to_cstring(button_label, context.temp_allocator)

            _ui_button_with_color(button_bound, button_label_c_string, padding = {}, color = state_color)
        }
        for perk, perk_val in DB.perk_data do if perk_val.buyable_state == .UnmetRequirements {
            buyable_data := DB.buyable_data[perk]
            button_bound := _ui_anchor({layout.bound.x + layout.at.x + i32(perk_scroll.x * ratio.w) , layout.bound.y + layout.at.y + i32(perk_scroll.y * ratio.h)},{0, 0, PERK_BUTTON_SIZE.width, PERK_BUTTON_SIZE.height})

            _ui_layout_advance(&layout, PERK_BUTTON_SIZE, .HORIZONTAL)
            button_label : string
            if !_is_message_active() && rl.CheckCollisionPointRec(rl.GetMousePosition(), _ui_rect(button_bound)) {
                button_label = fmt.tprint(perk_val.display, "\nCost: ", buyable_data.assigned_blocks_amount - buyable_data.bought_blocks_amount, sep = "") 
                if rl.IsMouseButtonPressed(.LEFT) do buy_perk(perk)
                if rl.IsMouseButtonPressed(.RIGHT) {
                    refund, err := refund_perk(perk)
                    if err != nil {
                        fmt.println(err)
                        _gui_blinker_start(perk, err)
                    }
                }
            }
            else do button_label = fmt.tprint(perk_val.display)
            button_label_c_string := strings.clone_to_cstring(button_label, context.temp_allocator)

            _ui_button_with_color(button_bound, button_label_c_string, padding = {}, color = rl.RED)
        }
    }
    rl.EndScissorMode()
}

_gui_draw_unit_panel :: proc (panel_bound: UIBound) {
    content_bound := _ui_content_from_panel(panel_bound)
    level_button_bound := _ui_anchor({content_bound.x, content_bound.y}, {0,0,content_bound.width,200})

    level_button_label := fmt.ctprint("Level:", DB.unit_level)
    _ui_button(level_button_bound, level_button_label, 25, line_spacing = 30)
    if !_is_message_active() && rl.CheckCollisionPointRec(rl.GetMousePosition(), _ui_rect(level_button_bound)) {
        if rl.IsMouseButtonPressed(.LEFT) do level_up()
        if rl.IsMouseButtonPressed(.RIGHT) {
            err := reduce_level()
            if err != nil do _gui_error(err)
            
        }
    }

    points_left_label := strings.clone_to_cstring(fmt.tprint(DB.unused_points, "\npoints left", sep=""), context.temp_allocator)
    points_left_bound := _ui_anchor({content_bound.x, content_bound.y+200},{0,0,content_bound.width,200})

    _ui_label(points_left_bound, points_left_label, font_size = 18, line_spacing = 30)
}

_gui_draw_skills_panel :: proc(panel_bound: UIBound) {
    _ui_draw_panel_layout({panel_bound.x, panel_bound.y}, gui_state.skills_panel_layout, panel_bound.width)
}


_gui_draw_main_skills_panel :: proc(panel_bound: UIBound) {
    MAIN_SKILL_FONT_SIZE :: 20
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
        skill := LeveledSkill{skill_id, skill_level}
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


        { // Make Invis and Disable Hover effects
            button_color_normal := rl.GuiGetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL))
            button_color_focused := rl.GuiGetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_FOCUSED))
            button_color_pressed := rl.GuiGetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_PRESSED))
            rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), 0x00000000)
            rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_FOCUSED), 0x00000000);
            rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_PRESSED), 0x00000000);
            defer {
                rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), button_color_normal)
                rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_FOCUSED), button_color_focused);
                rl.GuiSetStyle(.BUTTON, i32(rl.GuiControlProperty.BASE_COLOR_PRESSED), button_color_pressed);
            }
            _ui_button(button_bound, nil)
        }

        rl.GuiLock()
        
        button_label : cstring
        label_bound : UIBound
        if skill_level == 0 {
            label_bound = button_bound
            // state_color = rl.GRAY
            button_label = fmt.ctprint("Unlock\n",skill_name, sep = "") 
        }
        else {
            label_bound = owned_bound
            cap_bound := _ui_anchor(content_bottom_left+layout.at, _ui_bound_from_anchor(.BOTTOM_LEFT,{0, 0, button_bound.width, button_bound.height/MAX_SKILL_LEVEL*i32(slot_cap)}))
            _ui_button_with_color(cap_bound, color = rl.GRAY)
            button_label = fmt.ctprint(skill_name, skill_level) 
        }    
        
        if !_is_message_active() && rl.CheckCollisionPointRec(rl.GetMousePosition(), _ui_rect(button_bound)) {
            switch skill_id_data.raisable_state {
                case .NotEnoughPoints, .Raisable, .Capped:
                    button_label = fmt.ctprint(button_label, "\n", buyable_data.assigned_blocks_amount - buyable_data.bought_blocks_amount, " to raise", sep = "") 
                case .Free:
                    button_label = fmt.ctprint(button_label, "FREE to raise", sep = "\n") 
            }
            if rl.IsKeyPressed(.B) do print_buyable_blocks(next_skill)
            if rl.IsMouseButtonPressed(.RIGHT) {
                refund, err := reduce_skill(skill_id)
                if err != nil do _gui_blinker_start(skill,err)
            }
            if rl.IsMouseButtonPressed(.LEFT) do raise_skill(skill_id)
        }
        _ui_button_with_color(label_bound, button_label, font_size = MAIN_SKILL_FONT_SIZE,  color = state_color)

        rl.GuiUnlock()
        _ui_layout_advance(&layout, {SKILL_BUTTON_WIDTH+SEPARATOR, 0}, .HORIZONTAL)
    }
}

_gui_draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground(rl.WHITE)

    { // Main Draw
        _ui_draw_panel_layout({0,0}, gui_state.global_panel_layout, VRES_HEIGHT)
        if _is_message_active() {
            title: cstring
            content: cstring
            switch error in gui_state.message_box.error {
                case ReduceLevelError:
                    title = "Refund Error"
                    switch error_data in error {
                        case ReduceLevelErrorExceedsCap:
                            content = fmt.ctprint(error_data.skill_id, "exceeds cap")
                        case ReduceLevelErrorIrreducibleLevel:
                            content = fmt.ctprint("Can't reduce level 1")
                        case ReduceLevelErrorNotEnoughPoints:
                            content = fmt.ctprint("You need", error_data.points_deficit, "more points")
                    }
            }
            if rl.GuiMessageBox(_ui_rect(_ui_center_div({0,0,VRES_WIDTH, VRES_HEIGHT}, {300,200}, .Center)), title, content, "Ok") >= 0 {
                gui_state.message_box.remaining_time = 0
            }
        }
    }
    rl.EndDrawing()
}

_should_blink_perk :: proc(buyable: Buyable) -> bool {
    if gui_state.blinker.remaining_blinks <= 0 || !gui_state.blinker.active_blink do return false
    if buyable == gui_state.blinker.affected_buyable do return true
    switch gui_state.blinker.cause {
        case .None, .Unrefundable, .BuyableNotOwned:
        case .RequiredByAnotherBuyable:
            #partial switch perk in buyable {
                case PerkID:
                    #partial switch affected_buyable in gui_state.blinker.affected_buyable {
                    case PerkID:
                        if affected_buyable in _flattened_pre_reqs(perk) do return true
                    case LeveledSkill:
                        perk_val := DB.perk_data[perk]
                        for skill_req_entry in perk_val.skills_reqs {
                            switch req in skill_req_entry {
					            case LeveledSkill:
					            	if affected_buyable == req do return true
					            case SKILL_REQ_OR_GROUP:
					            	if slice.contains(req, affected_buyable) do return true 
					        }
                        }
                    }
            }
    }
    return false
}

DEFAULT_ERROR_MESSAGE_DURATION :: 3.0
_is_message_active :: proc() -> bool {
    return gui_state.message_box.remaining_time > 0
}
_gui_error :: proc(error: GUIMessageBoxError, duration: f32 = DEFAULT_ERROR_MESSAGE_DURATION) {
    gui_state.message_box.remaining_time = duration
    gui_state.message_box.error = error
}

DEFAULT_BLINK_TIME :: 1.0
DEFAULT_BLINK_AMOUNT :: 3
_gui_blinker_start :: proc(buyable: Buyable, refund_error: RefundError, duration: f32 = DEFAULT_BLINK_TIME, blinks: int = DEFAULT_BLINK_AMOUNT) {

    #partial switch refund_error {
        case .None, .Unrefundable, .BuyableNotOwned:
            return
    }
    gui_state.blinker.per_blink_time = duration / f32(blinks * 2)
    gui_state.blinker.remaining_time = gui_state.blinker.per_blink_time
    gui_state.blinker.remaining_blinks = blinks * 2
    gui_state.blinker.affected_buyable = buyable
    gui_state.blinker.cause = refund_error
    gui_state.blinker.active_blink = true
}

_gui_update :: proc() {
    if gui_state.blinker.remaining_blinks > 0 {
        if gui_state.blinker.remaining_time > 0 do gui_state.blinker.remaining_time -= rl.GetFrameTime()
        else {
            gui_state.blinker.active_blink = !gui_state.blinker.active_blink
            gui_state.blinker.remaining_time = gui_state.blinker.per_blink_time
            gui_state.blinker.remaining_blinks -= 1
        }
    }
    if gui_state.message_box.remaining_time > 0 do gui_state.message_box.remaining_time -= rl.GetFrameTime()
}

_gui_init_font :: proc() {
    gui_state.font = rl.LoadFont("res/DejaVuSansMono.ttf")
}

gui_run :: proc() {
    { // Init
        cfg := _cfg_default()
        // rl.SetTraceLogLevel( .WARNING )
        rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .WINDOW_RESIZABLE })
        rl.InitWindow( cfg.resolution_width, cfg.resolution_height, "Progression Interface" )
        rl.SetTargetFPS( cfg.max_fps )
        if cfg.fullscreen do rl.ToggleFullscreen()
        _gui_init_font()
        rl.GuiSetFont(gui_state.font)
        rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), 20)
    }
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)
        _gui_update()
        _gui_draw()
    }

    if rl.IsWindowReady() do rl.CloseWindow()
}

RefundBlink :: struct{
    per_blink_time      : f32,
    remaining_time      : f32,
    remaining_blinks    : int,
    active_blink        : bool,
    affected_buyable    : Buyable,
    cause               : RefundError,
}

GUIMessageBoxError :: union {
    ReduceLevelError,
}

GUIMessageBox :: struct {
    error: GUIMessageBoxError,
    remaining_time      : f32,
}

GUIState :: struct {
    blinker: RefundBlink,
    message_box: GUIMessageBox,
    font : rl.Font,

    

    skills_panel_layout: UIPanelLayout,
    global_panel_layout: UIPanelLayout,
}

gui_state := GUIState {
    skills_panel_layout = {
        distribution = {0, 50, 100},
        panels = {{name="Main Skills",draw=_gui_draw_main_skills_panel}, {name="Extra Skills",draw=_gui_draw_extra_skills_panel}},
        direction = .VERTICAL,
    },
    
    global_panel_layout = UIPanelLayout{
        distribution = {0, 25, 90, 100},
        panels = {{name="Perks",draw=_gui_draw_perks_panel}, {name="Skills",draw=_gui_draw_skills_panel}, {name="Unit",draw=_gui_draw_unit_panel}},
        direction = .HORIZONTAL,
    }

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
