local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Font = require("ui/font")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local NumberPickerWidget = require("ui/widget/numberpickerwidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Screen = Device.screen
local T = require("ffi/util").template

local DoubleSpinWidget = InputContainer:new{
    title_text = "",
    title_face = Font:getFace("x_smalltfont"),
    info_text = nil,
    width = nil,
    width_factor = nil, -- number between 0 and 1, factor to the smallest of screen width and height
    height = nil,
    left_text = _("Left"),
    left_min = 1,
    left_max = 20,
    left_value = 1,
    left_default = nil,
    left_precision = nil, -- default "%02d" in NumberPickerWidget
    left_wrap = false,
    right_text = _("Right"),
    right_min = 1,
    right_max = 20,
    right_value = 1,
    right_default = nil,
    right_precision = nil,
    right_wrap = false,
    cancel_text = _("Close"),
    ok_text = _("Apply"),
    cancel_callback = nil,
    callback = nil,
    close_callback = nil,
    keep_shown_on_apply = false,
    -- Set this to add upper default button that applies default values with callback(nil, nil)
    default_values = false,
    default_text = nil,
    -- Optional extra button above ok/cancel buttons row
    extra_text = nil,
    extra_callback = nil,
}

function DoubleSpinWidget:init()
    self.screen_width = Screen:getWidth()
    self.screen_height = Screen:getHeight()
    if not self.width then
        if not self.width_factor then
            self.width_factor = 0.8 -- default if no width speficied
        end
        self.width = math.floor(math.min(self.screen_width, self.screen_height) * self.width_factor)
    end
    if Device:hasKeys() then
        self.key_events = {
            Close = { {"Back"}, doc = "close doublespin widget" }
        }
    end
    if Device:isTouchDevice() then
        self.ges_events = {
            TapClose = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{
                        w = self.screen_width,
                        h = self.screen_height,
                    }
                },
            },
        }
    end

    -- Actually the widget layout
    self:update()
end

function DoubleSpinWidget:update(numberpicker_left_value, numberpicker_right_value)
    local left_widget = NumberPickerWidget:new{
        show_parent = self,
        value = numberpicker_left_value or self.left_value,
        value_min = self.left_min,
        value_max = self.left_max,
        value_step = self.left_step,
        value_hold_step = self.left_hold_step,
        precision = self.left_precision,
        wrap = self.left_wrap,
    }
    local right_widget = NumberPickerWidget:new{
        show_parent = self,
        value = numberpicker_right_value or self.right_value,
        value_min = self.right_min,
        value_max = self.right_max,
        value_step = self.right_step,
        value_hold_step = self.right_hold_step,
        precision = self.right_precision,
        wrap = self.right_wrap,
    }
    left_widget.picker_updated_callback = function(value)
        self:update(value, right_widget:getValue())
    end
    right_widget.picker_updated_callback = function(value)
        self:update(left_widget:getValue(), value)
    end
    
    local text_max_width = math.floor(0.95 * self.width / 2)
    local left_vertical_group = VerticalGroup:new{
        align = "center",
        TextWidget:new{
            text = self.left_text,
            face = self.title_face,
            max_width = text_max_width,
        },
        left_widget,
    }
    local right_vertical_group = VerticalGroup:new{
        align = "center",
        TextWidget:new{
            text = self.right_text,
            face = self.title_face,
            max_width = text_max_width,
        },
        right_widget,
    }
    local widget_group = HorizontalGroup:new{
        align = "center",
        CenterContainer:new{
            dimen = Geom:new{
                w = self.width / 2,
                h = left_vertical_group:getSize().h,
            },
            left_vertical_group
        },
        CenterContainer:new{
            dimen = Geom:new{
                w = self.width / 2,
                h = right_vertical_group:getSize().h,
            },
            right_vertical_group
        }
    }
    local widget_title = FrameContainer:new{
        padding = Size.padding.default,
        margin = Size.margin.title,
        bordersize = 0,
        TextWidget:new{
            text = self.title_text,
            face = self.title_face,
            max_width = self.width - 2 * (Size.padding.default + Size.margin.title),
        },
    }
    local widget_line = LineWidget:new{
        dimen = Geom:new{
            w = self.width,
            h = Size.line.thick,
        }
    }
    local widget_info
    if self.info_text then
        widget_info = FrameContainer:new{
            padding = Size.padding.default,
            margin = Size.margin.small,
            bordersize = 0,
            TextBoxWidget:new{
                text = self.info_text,
                face = Font:getFace("x_smallinfofont"),
                width = math.floor(self.width * 0.9),
            }
        }
    else
        widget_info = VerticalSpan:new{ width = 0 }
    end

    local buttons = {}
    if self.default_values then
        table.insert(buttons, {
            {
                text = self.default_text or T(_("Apply default values: %1 / %2"),
                    self.left_precision and string.format(self.left_precision, self.left_default) or self.left_default,
                    self.right_precision and string.format(self.right_precision, self.right_default) or self.right_default),
                callback = function()
                    left_widget.value = self.left_default
                    right_widget.value = self.right_default
                    left_widget:update()
                    right_widget:update()
                    self.callback(nil, nil)
                end,
            }
        })
    end
    if self.extra_text then
        table.insert(buttons, {
            {
                text = self.extra_text,
                callback = function()
                    if self.extra_callback then
                        self.extra_callback(left_widget:getValue(), right_widget:getValue())
                    end
                    if not self.keep_shown_on_apply then -- assume extra wants it same as ok
                        self:onClose()
                    end
                end,
            },
        })
    end
    table.insert(buttons, {
        {
            text = self.cancel_text,
            callback = function()
                if self.cancel_callback then
                    self.cancel_callback()
                end
                self:onClose()
            end,
        },
        {
            text = self.ok_text,
            enabled = self.left_value ~= left_widget:getValue() or self.right_value ~= right_widget:getValue(),
            callback = function()
                self.left_value = left_widget:getValue()
                self.right_value = right_widget:getValue()
                if self.callback then
                    self.callback(self.left_value, self.right_value)
                end
                if self.keep_shown_on_apply then
                    self:update()
                else
                    self:onClose()
                end
            end,
        },
    })

    local button_table = ButtonTable:new{
        width = self.width - 2*Size.padding.default,
        buttons = buttons,
        zero_sep = true,
        show_parent = self,
    }

    self.widget_frame = FrameContainer:new{
        radius = Size.radius.window,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "left",
            widget_title,
            widget_line,
            widget_info,
            CenterContainer:new{
                dimen = Geom:new{
                    w = self.width,
                    h = widget_group:getSize().h + 4 * Size.padding.large,
                },
                widget_group
            },
            CenterContainer:new{
                dimen = Geom:new{
                    w = self.width,
                    h = button_table:getSize().h,
                },
                button_table
            }
        }
    }
    self.movable = MovableContainer:new{
        self.widget_frame,
    }
    self[1] = WidgetContainer:new{
        align = "center",
        dimen = Geom:new{
            x = 0, y = 0,
            w = self.screen_width,
            h = self.screen_height,
        },
        self.movable,
    }
    UIManager:setDirty(self, function()
        return "ui", self.widget_frame.dimen
    end)
end

function DoubleSpinWidget:hasMoved()
    local offset = self.movable:getMovedOffset()
    return offset.x ~= 0 or offset.y ~= 0
end

function DoubleSpinWidget:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self.widget_frame.dimen
    end)
end

function DoubleSpinWidget:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.widget_frame.dimen
    end)
    return true
end

function DoubleSpinWidget:onAnyKeyPressed()
    self:onClose()
    return true
end

function DoubleSpinWidget:onTapClose(arg, ges_ev)
    if ges_ev.pos:notIntersectWith(self.widget_frame.dimen) then
        self:onClose()
    end
    return true
end

function DoubleSpinWidget:onClose()
    UIManager:close(self)
    if self.close_callback then
        self.close_callback()
    end
    return true
end

return DoubleSpinWidget
