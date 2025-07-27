---------------------------------------------------------------------------
-- Treasure · themes.lua · Waky
---------------------------------------------------------------------------

local imgui = require('imgui')
local ImGuiCol = imgui.Col

local THEMES = {
    Default = {
        [ImGuiCol_WindowBg] = { 0.12, 0.12, 0.12, 0.94 },
        [ImGuiCol_FrameBg] = { 0.20, 0.20, 0.20, 1.00 },
        [ImGuiCol_FrameBgHovered] = { 0.40, 0.00, 0.00, 0.68 },
        [ImGuiCol_Text] = { 1.00, 1.00, 1.00, 1.00 },
    },
    White = {
        [ImGuiCol_WindowBg] = { 1.00, 1.00, 1.00, 0.94 },
        [ImGuiCol_FrameBg] = { 0.90, 0.90, 0.90, 1.00 },
        [ImGuiCol_FrameBgHovered] = { 1.00, 0.80, 0.80, 0.78 },
        [ImGuiCol_Text] = { 0.00, 0.00, 0.00, 1.00 },
    },
    Dark = {
        [ImGuiCol_WindowBg] = { 0.06, 0.06, 0.06, 0.94 },
        [ImGuiCol_FrameBg] = { 0.10, 0.10, 0.10, 1.00 },
        [ImGuiCol_FrameBgHovered] = { 0.20, 0.20, 0.20, 0.78 },
        [ImGuiCol_Text] = { 0.85, 0.85, 0.85, 1.00 },
    },
    Grey = {
        [ImGuiCol_WindowBg] = { 0.30, 0.30, 0.30, 0.94 },
        [ImGuiCol_FrameBg] = { 0.40, 0.40, 0.40, 1.00 },
        [ImGuiCol_FrameBgHovered] = { 0.50, 0.50, 0.50, 0.78 },
        [ImGuiCol_Text] = { 0.95, 0.95, 0.95, 1.00 },
    },
    Red = {
        [ImGuiCol_WindowBg] = { 0.20, 0.00, 0.00, 0.94 },
        [ImGuiCol_FrameBg] = { 0.30, 0.00, 0.00, 1.00 },
        [ImGuiCol_FrameBgHovered] = { 0.50, 0.00, 0.00, 0.78 },
        [ImGuiCol_Text] = { 1.00, 0.80, 0.80, 1.00 },
    },

    -- New themes:
    Yellow = {
        [ImGuiCol_WindowBg] = { 0.94, 0.94, 0.12, 0.94 },
        [ImGuiCol_FrameBg] = { 1.00, 1.00, 0.50, 1.00 },
        [ImGuiCol_FrameBgHovered] = { 1.00, 1.00, 0.70, 0.78 },
        [ImGuiCol_Text] = { 0.10, 0.10, 0.10, 1.00 },
    },
    Blue = {
        [ImGuiCol_WindowBg] = { 0.10, 0.10, 0.50, 0.94 },
        [ImGuiCol_FrameBg] = { 0.15, 0.15, 0.70, 1.00 },
        [ImGuiCol_FrameBgHovered] = { 0.30, 0.30, 1.00, 0.78 },
        [ImGuiCol_Text] = { 0.80, 0.80, 1.00, 1.00 },
    },
    Teal = {
        [ImGuiCol_WindowBg] = { 0.10, 0.30, 0.30, 0.94 },
        [ImGuiCol_FrameBg] = { 0.15, 0.45, 0.45, 1.00 },
        [ImGuiCol_FrameBgHovered] = { 0.30, 0.70, 0.70, 0.78 },
        [ImGuiCol_Text] = { 1.00, 1.00, 1.00, 1.00 },
    },
}

return THEMES
