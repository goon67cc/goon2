    -- Project Bob - Standalone GUI Framework
-- Features: 14 themes (no Arctic Frost), uptime/FPS/user watermark, blur slider,
--           Frame-based snow/rain particles, config save/load system

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local CoreGui
pcall(function() CoreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui") end)
if not CoreGui then
    pcall(function() CoreGui = LocalPlayer:WaitForChild("PlayerGui") end)
end
if not CoreGui then CoreGui = Instance.new("Folder") end
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local gethui = gethui or function()
    local ok, cg = pcall(function() return CoreGui end)
    if ok and cg and typeof(cg) == "Instance" then return cg end
    ok, cg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui") end)
    if ok and cg then return cg end
    return Instance.new("Folder")
end

local Mouse, Keys, Tween, Instances, CustomFont

local FromRGB = Color3.fromRGB
local FromHSV = Color3.fromHSV
local FromHex = Color3.fromHex

local RGBSequence = ColorSequence.new
local RGBSequenceKeypoint = ColorSequenceKeypoint.new
local NumSequence = NumberSequence.new
local NumSequenceKeypoint = NumberSequenceKeypoint.new

local UDim2New = UDim2.new
local UDimNew = UDim.new
local Vector2New = Vector2.new
local Vector3New = Vector3.new
local InstanceNew = Instance.new
local _espConnection

local renderTasks = {}
local heartbeatTasks = {}
local steppedTasks = {}

local atmosphereInstance, bloomInstance, colorCorrectionInstance, sunRaysInstance
local _customIds, skyboxInstance

local MathClamp = math.clamp
local MathFloor = math.floor
local _MathSin = math.sin
local _MathCos = math.cos
local _MathRound = math.round

local TableInsert = table.insert
local TableFind = table.find
local TableRemove = table.remove
local TableConcat = table.concat
local TableUnpack = table.unpack

local StringFormat = string.format
local StringFind = string.find
local StringGSub = string.gsub
local _StringSplit = string.split
local _StringSub = string.sub

-- Blur effect with smooth easing
local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Parent = game:GetService("Lighting")
BlurEffect.Size = 0
local BlurSetting = 0
local blurTween

local function applyBlur(intensity)
    local target = intensity
    if target == nil then target = BlurSetting end
    target = MathClamp(target, 0, 56)
    if blurTween then blurTween:Cancel() end
    blurTween = TweenService:Create(BlurEffect, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = target})
    blurTween:Play()
end

-- Snow/Rain particle system (Frame-based, no ParticleEmitter)
local ParticleHolder = Instance.new("Folder")
ParticleHolder.Name = "\0"
ParticleHolder.Parent = gethui() or CoreGui

local ParticleSettings = {
    Enabled = false,
    Mode = "Rain",
    Count = 50,
    SnowSpeed = 50
}

local ParticlePool = {}
local ActiveParticles = {}
local windGust = 0

local startParticleSystem = nil
local stopParticleSystem = nil
local cleanupParticles = nil

-- =========================================================
--  THEME PRESETS (25 themes - Arctic Frost removed)
-- =========================================================
local ThemePresets = {
    ["Default Purple"] = {
        Background = Color3.fromRGB(15, 15, 20),
        Inline = Color3.fromRGB(20, 20, 25),
        PageBackground = Color3.fromRGB(30, 30, 35),
        Border = Color3.fromRGB(10, 10, 10),
        Outline = Color3.fromRGB(27, 27, 32),
        Accent = Color3.fromRGB(235, 157, 255),
        Element = Color3.fromRGB(33, 33, 36),
        HoveredElement = Color3.fromRGB(40, 40, 43),
        Text = Color3.fromRGB(215, 215, 215),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Ocean Blue"] = {
        Background = Color3.fromRGB(10, 15, 25),
        Inline = Color3.fromRGB(15, 20, 30),
        PageBackground = Color3.fromRGB(25, 30, 40),
        Border = Color3.fromRGB(5, 10, 15),
        Outline = Color3.fromRGB(30, 35, 45),
        Accent = Color3.fromRGB(52, 152, 219),
        Element = Color3.fromRGB(35, 40, 50),
        HoveredElement = Color3.fromRGB(45, 50, 60),
        Text = Color3.fromRGB(220, 225, 235),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Emerald Green"] = {
        Background = Color3.fromRGB(10, 20, 15),
        Inline = Color3.fromRGB(15, 25, 20),
        PageBackground = Color3.fromRGB(25, 35, 30),
        Border = Color3.fromRGB(5, 15, 10),
        Outline = Color3.fromRGB(30, 40, 35),
        Accent = Color3.fromRGB(46, 204, 113),
        Element = Color3.fromRGB(35, 45, 40),
        HoveredElement = Color3.fromRGB(45, 55, 50),
        Text = Color3.fromRGB(220, 235, 225),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Crimson Red"] = {
        Background = Color3.fromRGB(25, 15, 15),
        Inline = Color3.fromRGB(30, 20, 20),
        PageBackground = Color3.fromRGB(40, 25, 25),
        Border = Color3.fromRGB(15, 5, 5),
        Outline = Color3.fromRGB(45, 30, 30),
        Accent = Color3.fromRGB(231, 76, 60),
        Element = Color3.fromRGB(50, 35, 35),
        HoveredElement = Color3.fromRGB(60, 45, 45),
        Text = Color3.fromRGB(235, 220, 220),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Golden Yellow"] = {
        Background = Color3.fromRGB(25, 25, 15),
        Inline = Color3.fromRGB(30, 30, 20),
        PageBackground = Color3.fromRGB(40, 40, 25),
        Border = Color3.fromRGB(15, 15, 5),
        Outline = Color3.fromRGB(45, 45, 30),
        Accent = Color3.fromRGB(241, 196, 15),
        Element = Color3.fromRGB(50, 50, 35),
        HoveredElement = Color3.fromRGB(60, 60, 45),
        Text = Color3.fromRGB(235, 235, 220),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Midnight Black"] = {
        Background = Color3.fromRGB(5, 5, 10),
        Inline = Color3.fromRGB(10, 10, 15),
        PageBackground = Color3.fromRGB(15, 15, 20),
        Border = Color3.fromRGB(0, 0, 5),
        Outline = Color3.fromRGB(20, 20, 25),
        Accent = Color3.fromRGB(155, 89, 182),
        Element = Color3.fromRGB(20, 20, 25),
        HoveredElement = Color3.fromRGB(30, 30, 35),
        Text = Color3.fromRGB(200, 200, 210),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Lavender Dream"] = {
        Background = Color3.fromRGB(18, 14, 28),
        Inline = Color3.fromRGB(25, 20, 38),
        PageBackground = Color3.fromRGB(35, 28, 50),
        Border = Color3.fromRGB(10, 8, 18),
        Outline = Color3.fromRGB(32, 26, 46),
        Accent = Color3.fromRGB(187, 134, 252),
        Element = Color3.fromRGB(40, 33, 56),
        HoveredElement = Color3.fromRGB(52, 42, 70),
        Text = Color3.fromRGB(225, 215, 240),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Charcoal Grey"] = {
        Background = Color3.fromRGB(14, 14, 16),
        Inline = Color3.fromRGB(20, 20, 22),
        PageBackground = Color3.fromRGB(28, 28, 30),
        Border = Color3.fromRGB(8, 8, 10),
        Outline = Color3.fromRGB(24, 24, 26),
        Accent = FromRGB(120, 130, 145),
        Element = Color3.fromRGB(34, 34, 36),
        HoveredElement = Color3.fromRGB(44, 44, 46),
        Text = Color3.fromRGB(210, 210, 215),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Forest Dark"] = {
        Background = Color3.fromRGB(8, 18, 12),
        Inline = Color3.fromRGB(13, 25, 17),
        PageBackground = Color3.fromRGB(20, 35, 24),
        Border = Color3.fromRGB(4, 12, 8),
        Outline = Color3.fromRGB(18, 30, 22),
        Accent = Color3.fromRGB(39, 174, 96),
        Element = Color3.fromRGB(26, 42, 30),
        HoveredElement = Color3.fromRGB(36, 55, 42),
        Text = Color3.fromRGB(215, 230, 220),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Cyberpunk Blue"] = {
        Background = Color3.fromRGB(8, 12, 25),
        Inline = Color3.fromRGB(12, 18, 35),
        PageBackground = Color3.fromRGB(18, 25, 48),
        Border = FromRGB(4, 8, 18),
        Outline = Color3.fromRGB(16, 22, 42),
        Accent = Color3.fromRGB(0, 188, 255),
        Element = Color3.fromRGB(22, 30, 55),
        HoveredElement = Color3.fromRGB(32, 42, 68),
        Text = Color3.fromRGB(200, 220, 255),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Amber Glow"] = {
        Background = Color3.fromRGB(25, 18, 10),
        Inline = Color3.fromRGB(32, 24, 14),
        PageBackground = Color3.fromRGB(42, 32, 20),
        Border = Color3.fromRGB(18, 12, 6),
        Outline = Color3.fromRGB(38, 28, 18),
        Accent = Color3.fromRGB(255, 179, 64),
        Element = Color3.fromRGB(48, 36, 22),
        HoveredElement = Color3.fromRGB(60, 46, 30),
        Text = Color3.fromRGB(240, 225, 200),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Blood Red"] = {
        Background = Color3.fromRGB(20, 8, 8),
        Inline = Color3.fromRGB(28, 12, 12),
        PageBackground = Color3.fromRGB(38, 18, 18),
        Border = Color3.fromRGB(14, 4, 4),
        Outline = Color3.fromRGB(34, 16, 16),
        Accent = Color3.fromRGB(192, 20, 30),
        Element = Color3.fromRGB(44, 22, 22),
        HoveredElement = Color3.fromRGB(56, 30, 30),
        Text = Color3.fromRGB(240, 210, 210),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Royal Gold"] = {
        Background = Color3.fromRGB(10, 10, 22),
        Inline = Color3.fromRGB(16, 16, 30),
        PageBackground = Color3.fromRGB(24, 24, 40),
        Border = Color3.fromRGB(6, 6, 16),
        Outline = Color3.fromRGB(22, 22, 36),
        Accent = Color3.fromRGB(255, 215, 0),
        Element = Color3.fromRGB(30, 30, 46),
        HoveredElement = Color3.fromRGB(40, 40, 58),
        Text = Color3.fromRGB(230, 230, 245),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Neon Pink"] = {
        Background = Color3.fromRGB(20, 10, 25),
        Inline = Color3.fromRGB(25, 15, 30),
        PageBackground = Color3.fromRGB(35, 20, 40),
        Border = Color3.fromRGB(10, 5, 15),
        Outline = Color3.fromRGB(40, 25, 45),
        Accent = Color3.fromRGB(255, 20, 147),
        Element = Color3.fromRGB(45, 30, 50),
        HoveredElement = Color3.fromRGB(55, 40, 60),
        Text = Color3.fromRGB(235, 220, 240),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Sunset Orange"] = {
        Background = Color3.fromRGB(30, 10, 15),
        Inline = Color3.fromRGB(40, 15, 20),
        PageBackground = Color3.fromRGB(55, 25, 30),
        Border = Color3.fromRGB(20, 5, 8),
        Outline = Color3.fromRGB(60, 30, 35),
        Accent = Color3.fromRGB(255, 100, 0),
        Element = Color3.fromRGB(50, 25, 30),
        HoveredElement = Color3.fromRGB(65, 35, 40),
        Text = Color3.fromRGB(255, 200, 150),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Deep Purple"] = {
        Background = Color3.fromRGB(10, 5, 20),
        Inline = Color3.fromRGB(16, 8, 28),
        PageBackground = Color3.fromRGB(24, 12, 38),
        Border = Color3.fromRGB(6, 3, 14),
        Outline = Color3.fromRGB(20, 10, 34),
        Accent = Color3.fromRGB(138, 43, 226),
        Element = Color3.fromRGB(30, 16, 44),
        HoveredElement = Color3.fromRGB(40, 22, 56),
        Text = Color3.fromRGB(220, 200, 240),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Minty Fresh"] = {
        Background = Color3.fromRGB(10, 22, 18),
        Inline = Color3.fromRGB(14, 30, 24),
        PageBackground = Color3.fromRGB(20, 40, 32),
        Border = Color3.fromRGB(6, 16, 12),
        Outline = Color3.fromRGB(18, 36, 28),
        Accent = Color3.fromRGB(26, 188, 156),
        Element = Color3.fromRGB(26, 48, 38),
        HoveredElement = Color3.fromRGB(34, 60, 48),
        Text = Color3.fromRGB(210, 240, 230),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Ice Cold"] = {
        Background = Color3.fromRGB(12, 18, 28),
        Inline = Color3.fromRGB(18, 26, 38),
        PageBackground = Color3.fromRGB(26, 36, 50),
        Border = Color3.fromRGB(8, 12, 20),
        Outline = Color3.fromRGB(22, 32, 46),
        Accent = Color3.fromRGB(100, 200, 255),
        Element = Color3.fromRGB(32, 42, 56),
        HoveredElement = Color3.fromRGB(42, 54, 70),
        Text = Color3.fromRGB(200, 230, 255),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Halloween"] = {
        Background = Color3.fromRGB(15, 10, 5),
        Inline = Color3.fromRGB(22, 14, 8),
        PageBackground = Color3.fromRGB(32, 20, 12),
        Border = Color3.fromRGB(10, 6, 3),
        Outline = Color3.fromRGB(28, 18, 10),
        Accent = Color3.fromRGB(255, 140, 0),
        Element = Color3.fromRGB(38, 24, 14),
        HoveredElement = Color3.fromRGB(50, 32, 20),
        Text = Color3.fromRGB(255, 220, 150),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Matrix Green"] = {
        Background = Color3.fromRGB(0, 5, 0),
        Inline = Color3.fromRGB(4, 12, 4),
        PageBackground = Color3.fromRGB(8, 20, 8),
        Border = Color3.fromRGB(0, 3, 0),
        Outline = Color3.fromRGB(6, 16, 6),
        Accent = Color3.fromRGB(0, 255, 0),
        Element = Color3.fromRGB(12, 26, 12),
        HoveredElement = Color3.fromRGB(18, 38, 18),
        Text = Color3.fromRGB(100, 255, 100),
        TextBorder = Color3.fromRGB(0, 10, 0)
    },
    ["Rose Gold"] = {
        Background = Color3.fromRGB(22, 12, 16),
        Inline = Color3.fromRGB(30, 18, 22),
        PageBackground = Color3.fromRGB(42, 26, 32),
        Border = Color3.fromRGB(16, 8, 10),
        Outline = Color3.fromRGB(36, 22, 28),
        Accent = Color3.fromRGB(255, 182, 193),
        Element = Color3.fromRGB(48, 30, 36),
        HoveredElement = Color3.fromRGB(60, 40, 48),
        Text = Color3.fromRGB(240, 220, 225),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Toxic Green"] = {
        Background = Color3.fromRGB(5, 10, 5),
        Inline = Color3.fromRGB(10, 18, 10),
        PageBackground = Color3.fromRGB(16, 28, 16),
        Border = Color3.fromRGB(3, 6, 3),
        Outline = Color3.fromRGB(14, 24, 14),
        Accent = Color3.fromRGB(57, 255, 20),
        Element = Color3.fromRGB(22, 34, 22),
        HoveredElement = Color3.fromRGB(32, 46, 32),
        Text = Color3.fromRGB(180, 255, 160),
        TextBorder = Color3.fromRGB(0, 6, 0)
    },
    ["Coral Reef"] = {
        Background = Color3.fromRGB(25, 14, 12),
        Inline = Color3.fromRGB(34, 20, 16),
        PageBackground = Color3.fromRGB(46, 28, 22),
        Border = Color3.fromRGB(18, 8, 6),
        Outline = Color3.fromRGB(40, 24, 20),
        Accent = Color3.fromRGB(255, 127, 80),
        Element = Color3.fromRGB(52, 32, 26),
        HoveredElement = Color3.fromRGB(65, 42, 36),
        Text = Color3.fromRGB(245, 220, 210),
        TextBorder = Color3.fromRGB(0, 0, 0)
    },
    ["Midnight Blue"] = {
        Background = Color3.fromRGB(5, 5, 18),
        Inline = Color3.fromRGB(10, 10, 26),
        PageBackground = Color3.fromRGB(16, 16, 36),
        Border = Color3.fromRGB(3, 3, 12),
        Outline = Color3.fromRGB(14, 14, 32),
        Accent = Color3.fromRGB(25, 25, 200),
        Element = Color3.fromRGB(20, 20, 42),
        HoveredElement = Color3.fromRGB(28, 28, 54),
        Text = Color3.fromRGB(200, 200, 255),
        TextBorder = Color3.fromRGB(0, 0, 0)
    }
}

-- =========================================================
--  THUGSENSE LIBRARY (GUI ONLY)
-- =========================================================
local Aimbot, silentAimConn, gunModsConn, npcScanThread, npcAddedConn
local Library do
    Mouse = LocalPlayer:GetMouse()

    Library = {
        Flags = {},

        Theme = {
            ["Background"]       = FromRGB(15, 15, 20),
            ["Inline"]           = FromRGB(20, 20, 25),
            ["Page Background"]  = FromRGB(30, 30, 35),
            ["Border"]           = FromRGB(10, 10, 10),
            ["Outline"]          = FromRGB(27, 27, 32),
            ["Accent"]           = FromRGB(235, 157, 255),
            ["Element"]          = FromRGB(33, 33, 36),
            ["Hovered Element"]  = FromRGB(40, 40, 43),
            ["Text"]             = FromRGB(215, 215, 215),
            ["Text Border"]      = FromRGB(0, 0, 0)
        },

        MenuKeybind = "Enum.KeyCode.Z",

        Tween = {
            Time      = 0.3,
            Style     = Enum.EasingStyle.Exponential,
            Direction = Enum.EasingDirection.Out
        },

        Folders = {
            Directory = "ProjectBob",
            Configs   = "ProjectBob/Configs",
            Assets    = "ProjectBob/Assets"
        },

        Images = {
            ["Saturation"] = {"Saturation.png", "https://github.com/sametexe001/images/blob/main/saturation.png?raw=true"},
            ["Value"]      = {"Value.png",      "https://github.com/sametexe001/images/blob/main/value.png?raw=true"},
            ["Hue"]        = {"Hue.png",        "https://github.com/sametexe001/images/blob/main/hue.png?raw=true"},
            ["Scrollbar"]  = {"Scrollbar.png",  "https://github.com/sametexe001/images/blob/main/scrollbar.png?raw=true"},
            ["Checkers"]   = {"Checkers.png",   "https://github.com/sametexe001/images/blob/main/checkers.png?raw=true"},
            ["Resize"]     = {"Resize.png",     "https://github.com/sametexe001/images/blob/main/resize.png?raw=true"},
        },

        Pages            = {},
        Sections         = {},
        Connections      = {},
        Threads          = {},
        ThemeMap         = {},
        ThemeItems       = {},
        SetFlags         = {},
        UnnamedConnections = 0,
        UnnamedFlags     = 0,
        Holder           = nil,
        NotifHolder      = nil,
        Font             = nil,
        KeyList          = nil,
        CurrentColorpicker = nil
    }

    Library.__index = Library
    Library.Sections.__index = Library.Sections
    Library.Pages.__index    = Library.Pages

    Keys = {
        ["Unknown"]="Unknown",["Backspace"]="Back",["Tab"]="Tab",["Clear"]="Clear",
        ["Return"]="Return",["Pause"]="Pause",["Escape"]="Escape",["Space"]="Space",
        ["QuotedDouble"]='"',["Hash"]="#",["Dollar"]="$",["Percent"]="%",
        ["Ampersand"]="&",["Quote"]="'",["LeftParenthesis"]="(",["RightParenthesis"]=" )",
        ["Asterisk"]="*",["Plus"]="+",["Comma"]=",",["Minus"]="-",["Period"]=".",
        ["Slash"]="`",["Three"]="3",["Seven"]="7",["Eight"]="8",["Colon"]=":",
        ["Semicolon"]=";",["LessThan"]="<",["GreaterThan"]=">",["Question"]="?",
        ["Equals"]="=",["At"]="@",["LeftBracket"]="LeftBracket",["RightBracket"]="RightBracked",
        ["BackSlash"]="BackSlash",["Caret"]="^",["Underscore"]="_",["Backquote"]="`",
        ["LeftCurly"]="{",["Pipe"]="|",["RightCurly"]="}",["Tilde"]="~",
        ["Delete"]="Delete",["End"]="End",
        ["KeypadZero"]="Keypad0",["KeypadOne"]="Keypad1",["KeypadTwo"]="Keypad2",
        ["KeypadThree"]="Keypad3",["KeypadFour"]="Keypad4",["KeypadFive"]="Keypad5",
        ["KeypadSix"]="Keypad6",["KeypadSeven"]="Keypad7",["KeypadEight"]="Keypad8",
        ["KeypadNine"]="Keypad9",["KeypadPeriod"]="KeypadP",["KeypadDivide"]="KeypadD",
        ["KeypadMultiply"]="KeypadM",["KeypadMinus"]="KeypadM",["KeypadPlus"]="KeypadP",
        ["KeypadEnter"]="KeypadE",["KeypadEquals"]="KeypadE",["Insert"]="Insert",
        ["Home"]="Home",["PageUp"]="PageUp",["PageDown"]="PageDown",
        ["RightShift"]="RightShift",["LeftShift"]="LeftShift",
        ["RightControl"]="RightControl",["LeftControl"]="LeftControl",
        ["LeftAlt"]="LeftAlt",["RightAlt"]="RightAlt"
    }

    -- Create folders if they don't exist
    for _, FolderName in pairs(Library.Folders) do
        if not isfolder(FolderName) then makefolder(FolderName) end
    end
    
    -- Download images if needed
    pcall(function()
        for _, ImageData in pairs(Library.Images) do
            local ImageName = ImageData[1]
            local ImageLink = ImageData[2]
            if not isfile(Library.Folders.Assets.."/"..ImageName) then
                pcall(function()
                    writefile(Library.Folders.Assets.."/"..ImageName, game:HttpGet(ImageLink))
                end)
            end
        end
    end)

    Tween = {}; do
        Tween.__index = Tween
        Tween.Create = function(self, Item, Info, Goal, IsRawItem)
            Item = IsRawItem and Item or Item.Instance
            Info = Info or TweenInfo.new(
                (Library and Library.Tween and Library.Tween.Time) or 0.3,
                (Library and Library.Tween and Library.Tween.Style) or Enum.EasingStyle.Exponential,
                (Library and Library.Tween and Library.Tween.Direction) or Enum.EasingDirection.Out
            )
            local ok, tween = pcall(TweenService.Create, TweenService, Item, Info, Goal)
            local NewTween = ok and {Tween=tween, Info=Info, Goal=Goal, Item=Item} or {}
            if not ok then return NewTween end
            NewTween.Tween:Play()
            setmetatable(NewTween, Tween)
            return NewTween
        end
        Tween.Get    = function(self) if not self.Tween then return end; return self.Tween,self.Info,self.Goal end
        Tween.Pause  = function(self) if self.Tween then self.Tween:Pause() end end
        Tween.Play   = function(self) if self.Tween then self.Tween:Play()  end end
        Tween.Clean  = function(self) if self.Tween then self.Tween:Pause(); self=nil end end
    end

    Instances = {}; do
        Instances.__index = Instances
        Instances.Create = function(self, Class, Properties)
            local NewItem = {Instance=InstanceNew(Class), Properties=Properties, Class=Class}
            setmetatable(NewItem, Instances)
            for Property, Value in pairs(NewItem.Properties) do
                pcall(function() NewItem.Instance[Property] = Value end)
            end
            return NewItem
        end
        Instances.Border = function(self)
            if not self.Instance then return end
            local UIStroke = Instances:Create("UIStroke",{Parent=self.Instance,Color=Library.Theme.Border,Thickness=1,LineJoinMode=Enum.LineJoinMode.Miter})
            UIStroke:AddToTheme({Color="Border"})
            return UIStroke
        end
        Instances.AddToTheme    = function(self,Properties) if self.Instance then Library:AddToTheme(self,Properties) end end
        Instances.ChangeItemTheme = function(self,Properties) if self.Instance then Library:ChangeItemTheme(self,Properties) end end
        Instances.Connect       = function(self,Event,Callback,Name)
            if not self.Instance then return end
            if not self.Instance[Event] then return end
            return Library:Connect(self.Instance[Event], Callback, Name)
        end
        Instances.Tween         = function(self,Info,Goal) if self.Instance then return Tween:Create(self,Info,Goal) end; return nil end
        Instances.Disconnect    = function(self,Name) if self.Instance then return Library:Disconnect(Name) end; return nil end
        Instances.Clean         = function(self) if self.Instance then self.Instance:Destroy(); self=nil end end
        Instances.MakeDraggable = function(self)
            if not self.Instance then return end
            local Gui=self.Instance; local Dragging=false; local DragStart; local StartPosition
            local Set=function(Input)
                local DragDelta=Input.Position-DragStart
                self:Tween(TweenInfo.new(0.16,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2New(StartPosition.X.Scale,StartPosition.X.Offset+DragDelta.X,StartPosition.Y.Scale,StartPosition.Y.Offset+DragDelta.Y)})
            end
            Gui.InputBegan:Connect(function(Input)
                if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then
                    Dragging=true; DragStart=Input.Position; StartPosition=Gui.Position
                end
            end)
            Gui.InputEnded:Connect(function(Input)
                if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then Dragging=false end
            end)
            UserInputService.InputChanged:Connect(function(Input)
                if (Input.UserInputType==Enum.UserInputType.MouseMovement or Input.UserInputType==Enum.UserInputType.Touch) and Dragging then Set(Input) end
            end)
            return Dragging
        end
        Instances.MakeResizeable = function(self, Minimum, Maximum)
            if not self.Instance then return end
            local Gui=self.Instance; local Resizing=false; local Start=UDim2New(); local Delta=UDim2New()
            local ResizeMax=Gui.Parent.AbsoluteSize-Gui.AbsoluteSize
            local ResizeButton=Instances:Create("TextButton",{Parent=Gui,AnchorPoint=Vector2New(1,1),BorderColor3=FromRGB(0,0,0),Size=UDim2New(0,12,0,12),Position=UDim2New(1,0,1,0),Name="\0",BorderSizePixel=1,BackgroundTransparency=0.7,AutoButtonColor=false,Visible=true,Text="",BackgroundColor3=FromRGB(80,80,80)})
            ResizeButton:Connect("InputBegan",function(Input)
                if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then Resizing=true; Start=Gui.Size-UDim2New(0,Input.Position.X,0,Input.Position.Y) end
            end)
            ResizeButton:Connect("InputEnded",function(Input)
                if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then Resizing=false end
            end)
            Library:Connect(UserInputService.InputChanged,function(Input)
                if Input.UserInputType==Enum.UserInputType.MouseMovement and Resizing then
                    ResizeMax=Maximum or Gui.Parent.AbsoluteSize-Gui.AbsoluteSize
                    Delta=Start+UDim2New(0,Input.Position.X,0,Input.Position.Y)
                    Delta=UDim2New(0,math.clamp(Delta.X.Offset,Minimum.X,ResizeMax.X),0,math.clamp(Delta.Y.Offset,Minimum.Y,ResizeMax.Y))
                    Tween:Create(Gui,TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=Delta},true)
                end
            end)
            return Resizing
        end
        Instances.OnHover      = function(self,Function) if self.Instance then return Library:Connect(self.Instance.MouseEnter,Function) end; return nil end
        Instances.OnHoverLeave = function(self,Function) if self.Instance then return Library:Connect(self.Instance.MouseLeave,Function) end; return nil end
    end

    CustomFont = {}; do
        local FontCache = {}
        local function safeFont(contentId)
            local success, _result = pcall(Font.new, contentId)
            return success and _result or Font.fromEnum(Enum.Font.SourceSans)
        end
        function CustomFont:New(Name,Weight,Style,Data)
            if FontCache[Name] then return FontCache[Name] end
            local assetFolder = Library.Folders.Assets
            local jsonPath = assetFolder.."/"..Name..".json"
            local ttfPath = assetFolder.."/"..Name..".ttf"
            if isfile(jsonPath) then
                local f = safeFont(getcustomasset(jsonPath))
                FontCache[Name] = f
                return f
            end
            if not isfile(ttfPath) then
                local ok, data = pcall(game.HttpGet, game, Data.Url)
                if ok and data and #data > 0 then
                    writefile(ttfPath, data)
                else
                    FontCache[Name] = Font.fromEnum(Enum.Font.SourceSans)
                    return FontCache[Name]
                end
            end
            local ok, assetId = pcall(getcustomasset, ttfPath)
            if not ok then
                FontCache[Name] = Font.fromEnum(Enum.Font.SourceSans)
                return FontCache[Name]
            end
            local FontData={name=Name,faces={{name="Regular",weight=Weight,style=Style,assetId=assetId}}}
            writefile(jsonPath,HttpService:JSONEncode(FontData))
            local f = safeFont(getcustomasset(jsonPath))
            FontCache[Name] = f
            return f
        end
        function CustomFont:Get(Name)
            if FontCache[Name] then return FontCache[Name] end
            local jsonPath = Library.Folders.Assets.."/"..Name..".json"
            if isfile(jsonPath) then
                local f = safeFont(getcustomasset(jsonPath))
                FontCache[Name] = f
                return f
            end
            return Font.fromEnum(Enum.Font.SourceSans)
        end
        pcall(CustomFont.New, CustomFont, "Windows-XP-Tahoma",200,"Regular",{Url="https://github.com/sametexe001/luas/raw/refs/heads/main/fonts/windows-xp-tahoma.ttf"})
        pcall(CustomFont.New, CustomFont, "Roboto",400,"Regular",{Url="https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Inter",400,"Regular",{Url="https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Open Sans",400,"Regular",{Url="https://github.com/google/fonts/raw/main/apache/opensans/OpenSans-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Montserrat",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Poppins",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/poppins/Poppins-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Fira Code",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/firacode/FiraCode-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Source Sans Pro",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/sourcesanspro/SourceSansPro-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Lato",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/lato/Lato-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Nunito",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/nunito/Nunito-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Oswald",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/oswald/Oswald-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Raleway",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/raleway/Raleway-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Ubuntu",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ufl/ubuntu/Ubuntu-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Playfair Display",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/playfairdisplay/PlayfairDisplay-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Merriweather",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/merriweather/Merriweather-Regular.ttf"})
        pcall(CustomFont.New, CustomFont, "Comic Neue",400,"Regular",{Url="https://github.com/google/fonts/raw/main/ofl/comicneue/ComicNeue-Regular.ttf"})
        Library.Font = CustomFont:Get("Windows-XP-Tahoma")

        Library.FontList = {"Windows-XP-Tahoma", "Roboto", "Inter", "Open Sans", "Montserrat", "Poppins", "Fira Code", "Source Sans Pro", "Lato", "Nunito", "Oswald", "Raleway", "Ubuntu", "Playfair Display", "Merriweather", "Comic Neue"}
    end

    Library.Holder = Instances:Create("ScreenGui",{Parent=gethui(),Name="\0",ResetOnSpawn=false})
    Library.NotifHolder = Instances:Create("Frame",{Parent=Library.Holder.Instance,BorderColor3=FromRGB(0,0,0),AnchorPoint=Vector2New(0,0),BackgroundTransparency=1,Position=UDim2New(0,5,0,40),Name="\0",Size=UDim2New(0,400,1,-55),BorderSizePixel=0,BackgroundColor3=FromRGB(15,15,20)})
    Instances:Create("UIListLayout",{Parent=Library.NotifHolder.Instance,VerticalAlignment=Enum.VerticalAlignment.Top,SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center,Padding=UDimNew(0,10)})

    Library.GetImage = function(self,Image)
        local ImageData=self.Images[Image]; if not ImageData then return "" end
        local ok, _result = pcall(getcustomasset, self.Folders.Assets.."/"..ImageData[1])
        return ok and _result or ""
    end
    Library.Round = function(self,Number,Float) Float = (Float ~= nil and Float ~= 0) and Float or 1; local Multiplier=10^Float; return MathFloor(Number*Multiplier+0.5)/Multiplier end
    Library.GetTransparencyPropertyFromItem = function(self,Item)
        if Item:IsA("Frame") then return{"BackgroundTransparency"}
        elseif Item:IsA("TextLabel") or Item:IsA("TextButton") then return{"TextTransparency","BackgroundTransparency"}
        elseif Item:IsA("ImageLabel") or Item:IsA("ImageButton") then return{"BackgroundTransparency","ImageTransparency"}
        elseif Item:IsA("ScrollingFrame") then return{"BackgroundTransparency","ScrollBarImageTransparency"}
        elseif Item:IsA("TextBox") then return{"TextTransparency","BackgroundTransparency"}
        elseif Item:IsA("UIStroke") then return{"Transparency"} end
        return nil
    end
    Library.FadeItem = function(self,Item,Property,Visibility,Speed)
        local OldTransparency=Item[Property]; Item[Property]=Visibility and 1 or OldTransparency
        local NewTween=Tween:Create(Item,TweenInfo.new(Speed or Library.Tween.Time,Library.Tween.Style,Library.Tween.Direction),{[Property]=Visibility and OldTransparency or 1},true)
        Library:Connect(NewTween.Tween.Completed,function() if not Visibility then task.wait(); Item[Property]=OldTransparency end end)
        return NewTween
    end

    -- Merged task loops (reduces RunService connections)
    renderTasks = {}
    heartbeatTasks = {}
    steppedTasks = {}

    RunService.RenderStepped:Connect(function()
        for _, fn in pairs(renderTasks) do
            local _ok, _err = pcall(fn)
        end
    end)

    RunService.Heartbeat:Connect(function(dt)
        for _, fn in pairs(heartbeatTasks) do
            local _ok, _err = pcall(fn, dt)
        end
    end)

    RunService.Stepped:Connect(function(_, dt)
        for _, fn in pairs(steppedTasks) do
            local _ok, _err = pcall(fn, dt)
        end
    end)

    -- FPS counter
    local frameCount = 0
    local lastTime = tick()
    local currentFPS = 0
    renderTasks.FPS = function()
        frameCount = frameCount + 1
        local now = tick()
        if now - lastTime >= 1 then
            currentFPS = frameCount
            frameCount = 0
            lastTime = now
        end
    end

    Library.Unload = function(self)
        stopParticleSystem()

        local previewFrame = Library.Holder and Library.Holder.Instance and Library.Holder.Instance:FindFirstChild("OuterFrame", true)
        if previewFrame then previewFrame:Destroy() end

        heartbeatTasks.TimeCycle = function() end; heartbeatTasks.Fly = function() end; steppedTasks.NoClip = function() end
        if atmosphereInstance then atmosphereInstance:Destroy(); atmosphereInstance = nil end
        if bloomInstance then bloomInstance:Destroy(); bloomInstance = nil end
        if colorCorrectionInstance then colorCorrectionInstance:Destroy(); colorCorrectionInstance = nil end
        if sunRaysInstance then sunRaysInstance:Destroy(); sunRaysInstance = nil end
        if _G.ESPLibrary then _G.ESPLibrary:Destroy(); _G.ESPLibrary = nil end
        if blurTween then blurTween:Cancel(); blurTween = nil end
        if silentAimConn then silentAimConn:Disconnect(); silentAimConn = nil end
        if gunModsConn then gunModsConn:Disconnect(); gunModsConn = nil end
        if npcAddedConn then npcAddedConn:Disconnect(); npcAddedConn = nil end
        if npcScanThread then task.cancel(npcScanThread); npcScanThread = nil end
        if Aimbot and Aimbot.FOVCircle then pcall(function() Aimbot.FOVCircle:Destroy() end); Aimbot.FOVCircle = nil end
        BlurEffect:Destroy()
        BlurEffect = nil
        pcall(function()
            local L = game:GetService("Lighting")
            local sky = L:FindFirstChildOfClass("Sky")
            if sky then sky:Destroy() end
            L.Ambient = Color3.fromRGB(127, 127, 127)
            L.FogColor = Color3.fromRGB(127, 127, 127)
            L.FogEnd = 100000
            L.FogStart = 0
        end)
        for _,Value in pairs(self.Connections) do Value.Connection:Disconnect() end
        for _,Value in pairs(self.Threads) do coroutine.close(Value) end
        if self.Holder then self.Holder:Clean() end
        Library=nil; getgenv().Library=nil
    end
    Library.Thread = function(self,Function)
        local NewThread=coroutine.create(Function)
        coroutine.wrap(function() coroutine.resume(NewThread) end)()
        TableInsert(self.Threads,NewThread)
        return NewThread
    end
    Library.SafeCall = function(self,Function,...)
        local Arguments={...}
        local Success,Result=pcall(Function,TableUnpack(Arguments))
        if not Success then 
            Library:Notification("Error caught in function, report this to the devs:\n"..tostring(Result),5,FromRGB(255,0,0))
            warn(Result)
            return false 
        end
        return Success
    end
    Library.Connect = function(self,Event,Callback,Name)
        Name=Name or StringFormat("Connection_%s_%s",self.UnnamedConnections+1,HttpService:GenerateGUID(false))
        local NewConnection={Event=Event,Callback=Callback,Name=Name,Connection=nil}
        Library:Thread(function() NewConnection.Connection=Event:Connect(Callback) end)
        TableInsert(self.Connections,NewConnection)
        return NewConnection
    end
    Library.Disconnect = function(self,Name) 
        for _,Connection in pairs(self.Connections) do 
            if Connection.Name==Name then 
                Connection.Connection:Disconnect()
                break 
            end
        end
    end
    Library.NextFlag = function(self) 
        local FlagNumber=self.UnnamedFlags+1
        self.UnnamedFlags = FlagNumber
        return StringFormat("Flag_Number_%s",FlagNumber) 
    end
    Library.AddToTheme = function(self,Item,Properties)
        if not Item then return end
        if type(Item) == "table" and Item.Instance then Item = Item.Instance end
        if not Item then return end
        local ThemeData={Item=Item,Properties=Properties}
        for Property,Value in pairs(ThemeData.Properties) do 
            if type(Value)=="string" then 
                Item[Property]=self.Theme[Value] 
            end 
        end
        TableInsert(self.ThemeItems,ThemeData)
        self.ThemeMap[Item]=ThemeData
    end
    Library.GetConfig = function(self)
        local Config={}
        Library:SafeCall(function()
            Config.Theme = {}
            for themeName, themeColor in pairs(Library.Theme) do
                Config.Theme[themeName] = {themeColor.R, themeColor.G, themeColor.B}
            end
            
            for Index,Value in pairs(Library.Flags) do
                if type(Value)=="table" and Value.Key then 
                    Config[Index]={Key=tostring(Value.Key),Mode=Value.Mode}
                elseif type(Value)=="table" and Value.Color then 
                    Config[Index]={Color="#"..Value.HexValue,Alpha=Value.Alpha}
                else 
                    Config[Index]=Value 
                end
            end
        end)
        return HttpService:JSONEncode(Config)
    end
    Library.LoadConfig = function(self,Config)
        local Decoded=HttpService:JSONDecode(Config)
        local Success=Library:SafeCall(function()
            if Decoded.Theme then
                for themeName, themeColor in pairs(Decoded.Theme) do
                    if Library.Theme[themeName] then
                        Library:ChangeTheme(themeName, Color3.fromRGB(themeColor[1], themeColor[2], themeColor[3]))
                    end
                end
            end
            
            for Index,Value in pairs(Decoded) do
                if Index == "Theme" then 
                    -- Skip, already handled
                elseif Index == "ThemePreset" then
                    -- Handle theme preset separately
                else
                    local SetFunction=Library.SetFlags[Index]
                    if SetFunction then
                        if type(Value)=="table" and Value.Key then 
                            SetFunction(Value)
                        elseif type(Value)=="table" and Value.Color then 
                            SetFunction(Value.Color,Value.Alpha)
                        else 
                            SetFunction(Value) 
                        end
                    end
                end
            end
        end)
        if Success then 
            Library:Notification("Successfully loaded config",5,Color3.fromRGB(0,255,0)) 
        end
    end
    Library.DeleteConfig = function(self,Config)
        local configPath = Library.Folders.Configs.."/"..Config
        if isfile(configPath) then 
            delfile(configPath)
            Library:Notification("Deleted config "..Config,5,Color3.fromRGB(0,255,0)) 
        end
    end
    Library.SaveConfig = function(self,Config)
        local configPath = Library.Folders.Configs.."/"..Config
        writefile(configPath, Library:GetConfig())
        Library:Notification("Saved config "..Config,5,Color3.fromRGB(0,255,0))
    end
    Library.ChangeItemTheme = function(self,Item,Properties)
        Item=Item.Instance or Item
        if not self.ThemeMap[Item] then return end
        self.ThemeMap[Item].Properties=Properties
    end
    Library.ChangeTheme = function(self,ThemeName,Color)
        self.Theme[ThemeName]=Color
        for _,Item in pairs(self.ThemeItems) do 
            for Property,Value in pairs(Item.Properties) do 
                if type(Value)=="string" and Value==ThemeName then 
                    Item.Item[Property]=Color 
                end 
            end 
        end
    end
    Library.ApplyThemePreset = function(self, presetName)
        local preset = ThemePresets[presetName]
        if not preset then return end
        
        self:ChangeTheme("Background", preset.Background)
        self:ChangeTheme("Inline", preset.Inline)
        self:ChangeTheme("Page Background", preset.PageBackground)
        self:ChangeTheme("Border", preset.Border)
        self:ChangeTheme("Outline", preset.Outline)
        self:ChangeTheme("Accent", preset.Accent)
        self:ChangeTheme("Element", preset.Element)
        self:ChangeTheme("Hovered Element", preset.HoveredElement)
        self:ChangeTheme("Text", preset.Text)
        self:ChangeTheme("Text Border", preset.TextBorder)
    end
    Library.IsMouseOverFrame = function(self,Frame)
        Frame=Frame.Instance
        local MousePosition=Vector2New(Mouse.X,Mouse.Y)
        return MousePosition.X>=Frame.AbsolutePosition.X and MousePosition.X<=Frame.AbsolutePosition.X+Frame.AbsoluteSize.X
            and MousePosition.Y>=Frame.AbsolutePosition.Y and MousePosition.Y<=Frame.AbsolutePosition.Y+Frame.AbsoluteSize.Y
    end

    Library.SetFont = function(self, fontName)
        local newFont = CustomFont:Get(fontName)
        if not newFont then return end
        Library.Font = newFont
        local function applyFont(obj)
            pcall(function()
                for _, child in ipairs(obj:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                        child.FontFace = newFont
                    end
                end
            end)
        end
        if self.Holder and self.Holder.Instance then applyFont(self.Holder.Instance) end
        if self.NotifHolder and self.NotifHolder.Instance then applyFont(self.NotifHolder.Instance) end
        for _, item in ipairs(self.ThemeItems) do
            pcall(function()
                if item.Item and (item.Item:IsA("TextLabel") or item.Item:IsA("TextButton") or item.Item:IsA("TextBox")) then
                    item.Item.FontFace = newFont
                end
            end)
        end
    end

    -- Uptime tracking
    local StartTime = tick()
    local function getUptime()
        local elapsed = tick() - StartTime
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local seconds = math.floor(elapsed % 60)
        return string.format("%02d:%02d:%02d", hours, minutes, seconds)
    end

    Library.Watermark = function(self,Name)
        local Watermark={}; local Items={}
        
        -- Create a compact single-line watermark
        Items["Watermark"]=Instances:Create("Frame",{Parent=Library.Holder.Instance,Size=UDim2New(0,380,0,20),Name="\0",Position=UDim2New(0,15,0,15),BorderColor3=FromRGB(10,10,10),BorderSizePixel=2,BackgroundColor3=FromRGB(15,15,20),AutomaticSize=Enum.AutomaticSize.X})
        Items["Watermark"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Library.NotifHolder.Instance.Parent = Items["Watermark"].Instance
        Library.NotifHolder.Instance.Position = UDim2New(0, 0, 0, 18)
        Library.NotifHolder.Instance.Size = UDim2New(1, -10, 0, 300)
        Instances:Create("UIStroke",{Parent=Items["Watermark"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIPadding",{Parent=Items["Watermark"].Instance,PaddingTop=UDimNew(0,2),PaddingRight=UDimNew(0,8),PaddingLeft=UDimNew(0,8)})
        
        -- Main text label that contains everything
        Items["Title"]=Instances:Create("TextLabel",{Parent=Items["Watermark"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="",Name="\0",Size=UDim2New(1,0,0,15),BackgroundTransparency=1,Position=UDim2New(0,0,0,1),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(15,15,20)})
        Items["Title"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Title"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        
        -- Accent line at the top
        Items["AccentLine"]=Instances:Create("Frame",{Parent=Items["Watermark"].Instance,Name="\0",Position=UDim2New(0,-5,0,-2),BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,10,0,2),BorderSizePixel=0,BackgroundColor3=FromRGB(235,157,255)})
        Items["AccentLine"]:AddToTheme({BackgroundColor3="Accent"})
        Instances:Create("UIGradient",{Parent=Items["AccentLine"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(235,157,255)),RGBSequenceKeypoint(1,FromRGB(65,65,65))}})
        
        -- Build version
        local buildVersion = "Developer Build v1.0"
        local projectName = "Project Bob"
        
        -- Format: "■ Project Name | Uptime: 00:00:00 | FPS: 00 | User: username | Build"
        local function formatWatermarkText()
            return string.format("■ %s | Uptime: %s | FPS: %d | User: %s | %s", 
                projectName, getUptime(), currentFPS, LocalPlayer.Name, buildVersion)
        end
        
        -- Update the watermark text
        local function updateWatermarkText()
            if Items["Title"] and Items["Title"].Instance then
                Items["Title"].Instance.Text = formatWatermarkText()
                -- Auto-adjust size based on text width
                local textWidth = Items["Title"].Instance.TextBounds.X + 20
                Items["Watermark"].Instance.Size = UDim2New(0, math.max(380, textWidth), 0, 20)
            end
        end
        
        -- Initial update
        updateWatermarkText()
        
        -- Update uptime and FPS periodically
        task.spawn(function()
            while true do
                task.wait(0.5)
                updateWatermarkText()
            end
        end)
        
        function Watermark:SetVisibility(Bool)
            Items["Watermark"].Instance.Visible = Bool
            if Bool then
                Library.NotifHolder.Instance.Parent = Items["Watermark"].Instance
            else
                Library.NotifHolder.Instance.Parent = Library.Holder.Instance
            end
        end
        function Watermark:SetText(NewText) projectName = NewText; updateWatermarkText() end
        function Watermark:SetBuildVersion(NewVersion) buildVersion = NewVersion; updateWatermarkText() end
        function Watermark:SetSize(FontSize) 
            Items["Title"].Instance.TextSize=FontSize
            updateWatermarkText()
        end
        return Watermark
    end

    Library.Notification = function(self,Text,Duration,Color,Icon)
        local Items={}
        Items["Notification"]=Instances:Create("Frame",{Parent=Library.NotifHolder.Instance,Name="\0",Size=UDim2New(0,0,0,22),BorderColor3=FromRGB(10,10,10),BorderSizePixel=2,AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=FromRGB(15,15,20)})
        Items["Notification"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["Notification"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIPadding",{Parent=Items["Notification"].Instance,PaddingTop=UDimNew(0,1),PaddingRight=UDimNew(0,8),PaddingLeft=UDimNew(0,5)})
        Items["Title"]=Instances:Create("TextLabel",{Parent=Items["Notification"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Text,Name="\0",Size=UDim2New(1,0,0,15),BackgroundTransparency=1,Position=UDim2New(0,13,0,2),BorderSizePixel=0,AutomaticSize=Enum.AutomaticSize.X,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Title"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Title"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["AccentLine"]=Instances:Create("Frame",{Parent=Items["Notification"].Instance,Name="\0",Position=UDim2New(0,-5,0,-1),BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,13,0,2),BorderSizePixel=0,BackgroundColor3=Color})
        Instances:Create("UIGradient",{Parent=Items["AccentLine"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(65,65,65))}})
        Items["Title"].Instance.Position=UDim2New(0,1,0,2)
        Items["Notification"].Instance.BackgroundTransparency=1
        Items["Notification"].Instance.Size=UDim2New(0,0,0,0)
        for _,Value in pairs(Items["Notification"].Instance:GetDescendants()) do
            if Value:IsA("UIStroke") then 
                Value.Transparency=1
            elseif Value:IsA("TextLabel") then 
                Value.TextTransparency=1
            elseif Value:IsA("ImageLabel") then 
                Value.ImageTransparency=1
            elseif Value:IsA("Frame") then 
                Value.BackgroundTransparency=1
            end
        end
        Library:Thread(function()
            Items["Notification"]:Tween(nil,{BackgroundTransparency=0,Size=UDim2New(0,0,0,22)})
            task.wait(0.06)
            for _,Value in pairs(Items["Notification"].Instance:GetDescendants()) do
                if Value:IsA("UIStroke") then 
                    Tween:Create(Value,nil,{Transparency=0},true)
                elseif Value:IsA("TextLabel") then 
                    Tween:Create(Value,nil,{TextTransparency=0},true)
                elseif Value:IsA("ImageLabel") then 
                    Tween:Create(Value,nil,{ImageTransparency=0},true)
                elseif Value:IsA("Frame") then 
                    Tween:Create(Value,nil,{BackgroundTransparency=0},true)
                end
            end
            task.delay(Duration+0.1,function()
                for _,Value in pairs(Items["Notification"].Instance:GetDescendants()) do
                    if Value:IsA("UIStroke") then 
                        Tween:Create(Value,nil,{Transparency=1},true)
                    elseif Value:IsA("TextLabel") then 
                        Tween:Create(Value,nil,{TextTransparency=1},true)
                    elseif Value:IsA("ImageLabel") then 
                        Tween:Create(Value,nil,{ImageTransparency=1},true)
                    elseif Value:IsA("Frame") then 
                        Tween:Create(Value,nil,{BackgroundTransparency=1},true)
                    end
                end
                task.wait(0.06)
                Items["Notification"]:Tween(nil,{BackgroundTransparency=1,Size=UDim2New(0,0,0,0)})
                task.wait(0.5)
                Items["Notification"]:Clean()
            end)
        end)
    end

    Library.KeybindList = function(self)
        local KeybindList={}
        self.KeyList=KeybindList
        local Items={}
        Items["KeybindList"]=Instances:Create("Frame",{Parent=Library.Holder.Instance,BorderColor3=FromRGB(10,10,10),AnchorPoint=Vector2New(0,0.5),Name="\0",Position=UDim2New(0,15,0.5,0),Size=UDim2New(0,0,0,18),BorderSizePixel=2,AutomaticSize=Enum.AutomaticSize.XY,BackgroundColor3=FromRGB(15,15,20)})
        Items["KeybindList"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Items["KeybindList"]:MakeDraggable()
        Instances:Create("UIStroke",{Parent=Items["KeybindList"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["AccentLine"]=Instances:Create("Frame",{Parent=Items["KeybindList"].Instance,Name="\0",Position=UDim2New(0,-5,0,-5),BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,10,0,2),BorderSizePixel=0,BackgroundColor3=FromRGB(235,157,255)})
        Items["AccentLine"]:AddToTheme({BackgroundColor3="Accent"})
        Instances:Create("UIGradient",{Parent=Items["AccentLine"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(65,65,65))}})
        Instances:Create("UIPadding",{Parent=Items["KeybindList"].Instance,PaddingTop=UDimNew(0,5),PaddingBottom=UDimNew(0,5),PaddingRight=UDimNew(0,5),PaddingLeft=UDimNew(0,5)})
        Items["Title"]=Instances:Create("TextLabel",{Parent=Items["KeybindList"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="Keybinds",Name="\0",Size=UDim2New(0,100,0,15),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2New(0,0,0,-1),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Title"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Title"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["Content"]=Instances:Create("Frame",{Parent=Items["KeybindList"].Instance,Name="\0",BackgroundTransparency=1,Position=UDim2New(0,5,0,19),BorderColor3=FromRGB(0,0,0),BorderSizePixel=0,AutomaticSize=Enum.AutomaticSize.XY,BackgroundColor3=FromRGB(255,255,255)})
        Instances:Create("UIListLayout",{Parent=Items["Content"].Instance,Padding=UDimNew(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
        function KeybindList:Add(Mode,Name,Key)
            local NewKey=Instances:Create("TextLabel",{Parent=Items["Content"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="("..Mode..") "..Name.." - "..Key,Name="\0",Size=UDim2New(0,0,0,15),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,AutomaticSize=Enum.AutomaticSize.X,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
            NewKey:AddToTheme({TextColor3="Text"})
            Instances:Create("UIStroke",{Parent=NewKey.Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
            function NewKey:Set(Mode,Name,Key) 
                NewKey.Instance.Text="("..Mode..") "..Name.." - "..Key
            end
            function NewKey:SetStatus(Status) 
                if Status=="Active" then 
                    NewKey:Tween(nil,{TextColor3=Library.Theme.Accent})
                    NewKey:ChangeItemTheme({TextColor3="Accent"})
                else 
                    NewKey:Tween(nil,{TextColor3=Library.Theme.Text})
                    NewKey:ChangeItemTheme({TextColor3="Text"})
                end 
            end
            return NewKey
        end
        function KeybindList:SetVisibility(Bool) 
            Items["KeybindList"].Instance.Visible=Bool 
        end
        return KeybindList
    end

    Library.CreateColorpicker = function(self,Data)
        local Colorpicker={Hue=0,Saturation=0,Value=0,Alpha=0,HexValue="",IsOpen=false,Color=FromRGB(0,0,0),Class="Colorpicker"}
        Library.Flags[Data.Flag]={}
        local Items={}
        Items["ColorpickerButton"]=Instances:Create("TextButton",{Parent=Data.Parent.Instance,FontFace=Library.Font,TextColor3=FromRGB(0,0,0),BorderColor3=FromRGB(0,0,0),Text="",AutoButtonColor=false,AnchorPoint=Vector2New(1,0.5),Name="\0",Position=UDim2New(1,0,0.5,0),Size=UDim2New(0,20,0,10),BorderSizePixel=0,TextSize=14,BackgroundColor3=FromRGB(255,0,0)})
        Colorpicker.CalculateCount=function(self,Index,YScale,YOffset)
            local MaxButtonsAdded=5
            local Column=Index%MaxButtonsAdded
            local ButtonSize=Items["ColorpickerButton"].Instance.AbsoluteSize
            local Spacing=4
            local XPosition=(ButtonSize.X+Spacing)*Column-Spacing-21
            Items["ColorpickerButton"].Instance.Position=UDim2New(1,-XPosition,YScale or 0.5,YOffset or 0)
        end
        Colorpicker:CalculateCount(Data.Count)
        Instances:Create("UIStroke",{Parent=Items["ColorpickerButton"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIGradient",{Parent=Items["ColorpickerButton"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(100,100,100))}})
        Items["ColorpickerWindow"]=Instances:Create("TextButton",{Parent=Library.Holder.Instance,AutoButtonColor=false,Text="",Name="\0",Position=UDim2New(0,Data.Parent.Instance.AbsolutePosition.X,0,Data.Parent.Instance.AbsolutePosition.Y+15),BorderColor3=FromRGB(10,10,10),Visible=false,Size=UDim2New(0,238,0,224),BorderSizePixel=2,BackgroundColor3=FromRGB(15,15,20)})
        Items["ColorpickerWindow"]:AddToTheme({BackgroundColor3="Background"})
        Items["ColorpickerWindow"]:MakeDraggable()
        Items["ColorpickerWindow"]:MakeResizeable(Vector2New(200,180),Vector2New(9999,9999))
        Instances:Create("UIStroke",{Parent=Items["ColorpickerWindow"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["Title"]=Instances:Create("TextLabel",{Parent=Items["ColorpickerWindow"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Data.Name,Name="\0",Size=UDim2New(1,0,0,15),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2New(0,-2,0,-3),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Title"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Title"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["AccentLine"]=Instances:Create("Frame",{Parent=Items["ColorpickerWindow"].Instance,Name="\0",Position=UDim2New(0,-6,0,-6),BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,12,0,2),BorderSizePixel=0,BackgroundColor3=FromRGB(235,157,255)})
        Items["AccentLine"]:AddToTheme({BackgroundColor3="Accent"})
        Instances:Create("UIGradient",{Parent=Items["AccentLine"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(65,65,65))}})
        Instances:Create("UIPadding",{Parent=Items["ColorpickerWindow"].Instance,PaddingTop=UDimNew(0,6),PaddingBottom=UDimNew(0,6),PaddingRight=UDimNew(0,6),PaddingLeft=UDimNew(0,6)})
        Items["Palette"]=Instances:Create("TextButton",{Parent=Items["ColorpickerWindow"].Instance,FontFace=Library.Font,TextColor3=FromRGB(0,0,0),BorderColor3=FromRGB(0,0,0),Text="",AutoButtonColor=false,Name="\0",Position=UDim2New(0,0,0,15),Size=UDim2New(1,-26,1,-40),BorderSizePixel=0,TextSize=14,BackgroundColor3=FromRGB(255,0,0)})
        Items["Saturation"]=Instances:Create("ImageLabel",{Parent=Items["Palette"].Instance,BorderColor3=FromRGB(0,0,0),Image=Library:GetImage("Saturation"),BackgroundTransparency=1,Name="\0",Size=UDim2New(1,0,1,0),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Items["Value"]=Instances:Create("ImageLabel",{Parent=Items["Palette"].Instance,BorderColor3=FromRGB(0,0,0),Image=Library:GetImage("Value"),BackgroundTransparency=1,Name="\0",Size=UDim2New(1,0,1,0),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Instances:Create("UIStroke",{Parent=Items["Palette"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["PaletteDragger"]=Instances:Create("Frame",{Parent=Items["Palette"].Instance,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(0,2,0,2),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Instances:Create("UIStroke",{Parent=Items["PaletteDragger"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["Hue"]=Instances:Create("ImageButton",{Parent=Items["ColorpickerWindow"].Instance,BorderColor3=FromRGB(0,0,0),AutoButtonColor=false,AnchorPoint=Vector2New(1,0),Image=Library:GetImage("Hue"),Name="\0",Position=UDim2New(1,0,0,15),Size=UDim2New(0,18,1,-15),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Items["HueDragger"]=Instances:Create("Frame",{Parent=Items["Hue"].Instance,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,0,0,1),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Instances:Create("UIStroke",{Parent=Items["HueDragger"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIStroke",{Parent=Items["Hue"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["Alpha"]=Instances:Create("TextButton",{Parent=Items["ColorpickerWindow"].Instance,FontFace=Library.Font,TextColor3=FromRGB(0,0,0),BorderColor3=FromRGB(0,0,0),Text="",AutoButtonColor=false,AnchorPoint=Vector2New(0,1),Name="\0",Position=UDim2New(0,0,1,0),Size=UDim2New(1,-26,0,18),BorderSizePixel=0,TextSize=14,BackgroundColor3=FromRGB(255,0,0)})
        Instances:Create("UIStroke",{Parent=Items["Alpha"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["Checkers"]=Instances:Create("ImageLabel",{Parent=Items["Alpha"].Instance,ScaleType=Enum.ScaleType.Tile,BorderColor3=FromRGB(0,0,0),Image=Library:GetImage("Checkers"),TileSize=UDim2New(0,6,0,6),Name="\0",Size=UDim2New(1,0,1,0),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Instances:Create("UIGradient",{Parent=Items["Checkers"].Instance,Transparency=NumSequence{NumSequenceKeypoint(0,1),NumSequenceKeypoint(1,0)}})
        Instances:Create("UIGradient",{Parent=Items["Alpha"].Instance,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(0,0,0))}})
        Items["AlphaDragger"]=Instances:Create("Frame",{Parent=Items["Alpha"].Instance,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(0,1,1,0),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Instances:Create("UIStroke",{Parent=Items["AlphaDragger"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})

        local SlidingPalette=false
        local SlidingHue=false
        local SlidingAlpha=false
        local Debounce=false
        
        function Colorpicker:SetOpen(Bool)
            if Debounce then return end
            Colorpicker.IsOpen=Bool
            Debounce=true
            if Bool then
                Items["ColorpickerWindow"].Instance.Visible=true
                Items["ColorpickerWindow"].Instance.Position=UDim2New(0,Data.Parent.Instance.AbsolutePosition.X,0,Data.Parent.Instance.AbsolutePosition.Y+15)
                if Library.CurrentColorpicker then 
                    Library.CurrentColorpicker:SetOpen(false)
                    Library.CurrentColorpicker=nil 
                end
                if not Library.CurrentColorpicker then 
                    Library.CurrentColorpicker=Colorpicker 
                end
            else 
                Library.CurrentColorpicker=nil 
            end
            local Descendants=Items["ColorpickerWindow"].Instance:GetDescendants()
            TableInsert(Descendants,Items["ColorpickerWindow"].Instance)
            local NewTween
            for _,Value in pairs(Descendants) do
                local ValueIndex=Library:GetTransparencyPropertyFromItem(Value)
                if not ValueIndex then continue end
                if not StringFind(Value.ClassName,"UI") then 
                    Value.ZIndex=Bool and 10001 or 1 
                end
                if type(ValueIndex)=="table" then 
                    for _,Property in pairs(ValueIndex) do 
                        NewTween=Library:FadeItem(Value,Property,Bool,Data.FadeSpeed) 
                    end
                else 
                    NewTween=Library:FadeItem(Value,ValueIndex,Bool,Data.FadeSpeed) 
                end
            end
            Library:Connect(NewTween.Tween.Completed,function() 
                Debounce=false
                Items["ColorpickerWindow"].Instance.Visible=Bool 
            end)
        end
        
        function Colorpicker:Get() 
            return Colorpicker.Value 
        end
        
        function Colorpicker:SetVisibility(Bool) 
            Data.Parent.Instance.Visible=Bool 
        end
        
        function Colorpicker:Set(Color,Alpha)
            if type(Color)=="table" then 
                Color=FromRGB(Color[1],Color[2],Color[3])
                Alpha=Color[4]
            elseif type(Color)=="string" then 
                Color=FromHex(Color) 
            end
            self.Hue,self.Saturation,self.Value=Color:ToHSV()
            self.Alpha=Alpha or 0
            self.Color=FromHSV(self.Hue,self.Saturation,self.Value)
            self.HexValue=self.Color:ToHex()
            Library.Flags[Data.Flag]={Color=self.Color,HexValue=self.HexValue,Alpha=self.Alpha}
            Items["PaletteDragger"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2New(MathClamp(1-self.Saturation,0,0.989),0,MathClamp(1-self.Value,0,0.989),0)})
            Items["HueDragger"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2New(0,0,MathClamp(self.Hue,0,0.994),0)})
            Items["AlphaDragger"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2New(MathClamp(self.Alpha,0,0.994),0,0,0)})
            self:Update()
        end
        
        function Colorpicker:Update(IsFromAlpha)
            self.Color=FromHSV(self.Hue,self.Saturation,self.Value)
            self.HexValue=self.Color:ToHex()
            Library.Flags[Data.Flag]={Color=self.Color,HexValue=self.HexValue,Alpha=self.Alpha}
            Items["ColorpickerButton"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundColor3=self.Color})
            Items["Palette"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundColor3=FromHSV(self.Hue,1,1)})
            if not IsFromAlpha then 
                Items["Alpha"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundColor3=self.Color}) 
            end
            if Data.Callback then 
                Library:SafeCall(Data.Callback,self.Color,self.Alpha) 
            end
        end
        
        function Colorpicker:SlidePalette(Input)
            if not Input or not SlidingPalette then return end
            self.Saturation=MathClamp(1-(Input.Position.X-Items["Palette"].Instance.AbsolutePosition.X)/Items["Palette"].Instance.AbsoluteSize.X,0,1)
            self.Value=MathClamp(1-(Input.Position.Y-Items["Palette"].Instance.AbsolutePosition.Y)/Items["Palette"].Instance.AbsoluteSize.Y,0,1)
            Items["PaletteDragger"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2New(MathClamp((Input.Position.X-Items["Palette"].Instance.AbsolutePosition.X)/Items["Palette"].Instance.AbsoluteSize.X,0,0.989),0,MathClamp((Input.Position.Y-Items["Palette"].Instance.AbsolutePosition.Y)/Items["Palette"].Instance.AbsoluteSize.Y,0,0.989),0)})
            self:Update()
        end
        
        function Colorpicker:SlideHue(Input)
            if not Input or not SlidingHue then return end
            self.Hue=MathClamp((Input.Position.Y-Items["Hue"].Instance.AbsolutePosition.Y)/Items["Hue"].Instance.AbsoluteSize.Y,0,1)
            Items["HueDragger"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2New(0,0,MathClamp((Input.Position.Y-Items["Hue"].Instance.AbsolutePosition.Y)/Items["Hue"].Instance.AbsoluteSize.Y,0,0.994),0)})
            self:Update()
        end
        
        function Colorpicker:SlideAlpha(Input)
            if not Input or not SlidingAlpha then return end
            self.Alpha=MathClamp((Input.Position.X-Items["Alpha"].Instance.AbsolutePosition.X)/Items["Alpha"].Instance.AbsoluteSize.X,0,1)
            Items["AlphaDragger"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2New(MathClamp((Input.Position.X-Items["Alpha"].Instance.AbsolutePosition.X)/Items["Alpha"].Instance.AbsoluteSize.X,0,0.994),0,0,0)})
            self:Update(true)
        end
        
        Items["ColorpickerButton"]:Connect("MouseButton1Down",function() 
            Colorpicker:SetOpen(not Colorpicker.IsOpen) 
        end)
        Items["Palette"]:Connect("InputBegan",function(Input) 
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then 
                SlidingPalette=true
                Colorpicker:SlidePalette(Input) 
            end 
        end)
        Items["Palette"]:Connect("InputEnded",function(Input) 
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then 
                SlidingPalette=false 
            end 
        end)
        Items["Hue"]:Connect("InputBegan",function(Input) 
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then 
                SlidingHue=true
                Colorpicker:SlideHue(Input) 
            end 
        end)
        Items["Hue"]:Connect("InputEnded",function(Input) 
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then 
                SlidingHue=false 
            end 
        end)
        Items["Alpha"]:Connect("InputBegan",function(Input) 
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then 
                SlidingAlpha=true
                Colorpicker:SlideAlpha(Input) 
            end 
        end)
        Items["Alpha"]:Connect("InputEnded",function(Input) 
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then 
                SlidingAlpha=false 
            end 
        end)
        Library:Connect(UserInputService.InputChanged,function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseMovement then
                if SlidingPalette then Colorpicker:SlidePalette(Input) end
                if SlidingHue then Colorpicker:SlideHue(Input) end
                if SlidingAlpha then Colorpicker:SlideAlpha(Input) end
            end
        end)
        Library:Connect(UserInputService.InputBegan,function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then
                if Library:IsMouseOverFrame(Items["ColorpickerWindow"]) then return end
                Colorpicker:SetOpen(false)
            end        end)
        if Data.Default then 
            Colorpicker:Set(Data.Default,Data.Alpha) 
        end
        Library.SetFlags[Data.Flag]=function(Color,Alpha) 
            Colorpicker:Set(Color,Alpha) 
        end
        return Colorpicker
    end

    Library.CreateKeybind = function(self,Data)
        local Keybind={Key=nil,Value="",Mode="",Toggled=false,IsOpen=false,Picking=false,Class="Keybind"}
        Library.Flags[Data.Flag]={}
        local KeyListItem
        local Items={}
        Items["KeyButton"]=Instances:Create("TextButton",{Parent=Data.Parent.Instance,FontFace=Library.Font,TextColor3=FromRGB(0,0,0),BorderColor3=FromRGB(27,27,32),Text="",AutoButtonColor=false,AnchorPoint=Vector2New(1,0),Size=UDim2New(0,0,1,1),Name="\0",Position=UDim2New(1,0,0,0),BorderSizePixel=2,AutomaticSize=Enum.AutomaticSize.X,TextSize=14,BackgroundColor3=FromRGB(15,15,20)})
        Items["KeyButton"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Outline"})
        Instances:Create("UIStroke",{Parent=Items["KeyButton"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(10,10,10)}):AddToTheme({Color="Border"})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["KeyButton"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="NaN",Name="\0",BackgroundTransparency=1,Position=UDim2New(0,1,0,0),Size=UDim2New(1,0,1,0),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Instances:Create("UIPadding",{Parent=Items["KeyButton"].Instance,PaddingRight=UDimNew(0,3),PaddingLeft=UDimNew(0,3),PaddingBottom=UDimNew(0,2)})
        Items["Window"]=Instances:Create("Frame",{Parent=Data.Parent.Instance,BorderColor3=FromRGB(10,10,10),AnchorPoint=Vector2New(1,0),Name="\0",Position=UDim2New(1,0,1,5),Size=UDim2New(0,50,0,48),BorderSizePixel=2,Visible=false,BackgroundColor3=FromRGB(15,15,20)})
        Items["Window"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["Window"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["Toggle"]=Instances:Create("TextButton",{Parent=Items["Window"].Instance,FontFace=Library.Font,TextColor3=FromRGB(235,157,255),BorderColor3=FromRGB(0,0,0),Text="Toggle",AutoButtonColor=false,Name="\0",BorderSizePixel=0,BackgroundTransparency=1,Position=UDim2New(0,1,0,0),Size=UDim2New(1,0,0,15),TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Toggle"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Toggle"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["Hold"]=Instances:Create("TextButton",{Parent=Items["Window"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="Hold",AutoButtonColor=false,Name="\0",BorderSizePixel=0,BackgroundTransparency=1,Position=UDim2New(0,1,0,15),Size=UDim2New(1,0,0,15),TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Hold"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Hold"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["Always"]=Instances:Create("TextButton",{Parent=Items["Window"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="Always",AutoButtonColor=false,Name="\0",BorderSizePixel=0,BackgroundTransparency=1,Position=UDim2New(0,1,0,30),Size=UDim2New(1,0,0,15),TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Always"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Always"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        
        local Modes={["Toggle"]=Items["Toggle"],["Hold"]=Items["Hold"],["Always"]=Items["Always"]}
        local Update=function()
            local hasKey = Keybind.Key ~= nil and Keybind.Value ~= "" and Keybind.Value ~= "None"
            if hasKey then
                if not KeyListItem and Library.KeyList then
                    KeyListItem = Library.KeyList:Add(Keybind.Mode, Data.Name, Keybind.Value)
                end
                if KeyListItem then
                    KeyListItem:Set(Keybind.Mode, Data.Name, Keybind.Value)
                    KeyListItem:SetStatus(Keybind.Toggled and "Active" or "Inactive")
                end
            else
                if KeyListItem then
                    pcall(function() KeyListItem.Instance:Destroy() end)
                    KeyListItem = nil
                end
            end
        end
        
        function Keybind:Get() 
            return Keybind.Toggled,Keybind.Key,Keybind.Mode 
        end
        
        function Keybind:SetVisibility(Bool) 
            Data.Parent.Instance.Visible=Bool 
        end
        
        local Debounce=false
        
        function Keybind:SetOpen(Bool)
            Keybind.IsOpen=Bool
            if Bool then
                Debounce=true
                Items["Window"].Instance.Visible=true
                Items["Window"].Instance.ZIndex=16
                Items["Window"]:Tween(nil,{BackgroundTransparency=0})
                task.wait(0.1)
                for _,Value in pairs(Items["Window"].Instance:GetDescendants()) do
                    if Value:IsA("UIStroke") then 
                        Tween:Create(Value,nil,{Transparency=0},true)
                    elseif Value:IsA("TextButton") then 
                        Tween:Create(Value,nil,{TextTransparency=0},true)
                        Value.ZIndex=16 
                    end
                end
            else
                for _,Value in pairs(Items["Window"].Instance:GetDescendants()) do
                    if Value:IsA("UIStroke") then 
                        Tween:Create(Value,nil,{Transparency=1},true)
                    elseif Value:IsA("TextButton") then 
                        Tween:Create(Value,nil,{TextTransparency=1},true)
                        Value.ZIndex=1 
                    end
                end
                task.wait(0.1)
                Items["Window"]:Tween(nil,{BackgroundTransparency=1})
                Items["Window"].Instance.ZIndex=1
                task.wait(0.1)
                Items["Window"].Instance.Visible=false
            end
            Debounce=false
        end
        
        function Keybind:Set(Key)
            if StringFind(tostring(Key),"Enum") then
                Keybind.Key=tostring(Key)
                Key=Key.Name=="Backspace" and "None" or Key.Name
                local KeyString=Keys[Keybind.Key] or StringGSub(Key,"Enum.","") or "None"
                local TextToDisplay=StringGSub(StringGSub(KeyString,"KeyCode.",""),"UserInputType.","") or "None"
                Keybind.Value=TextToDisplay
                Items["Text"].Instance.Text=TextToDisplay
                if Data.Callback then 
                    Library:SafeCall(Data.Callback,Keybind.Toggled) 
                end
            elseif TableFind({"Toggle","Hold","Always"},Key) then
                Keybind.Mode=Key
                Keybind:SetMode(Key)
                if Data.Callback then 
                    Library:SafeCall(Data.Callback,Keybind.Toggled) 
                end
            elseif type(Key)=="table" then
                local RealKey=Key.Key=="Backspace" and "None" or Key.Key
                Keybind.Key=tostring(Key.Key)
                if Key.Mode then 
                    Keybind.Mode=Key.Mode
                    Keybind:SetMode(Key.Mode)
                else 
                    Keybind.Mode="Toggle"
                    Keybind:SetMode("Toggle") 
                end
                local KeyString=Keys[Keybind.Key] or StringGSub(tostring(RealKey),"Enum.","") or RealKey                
                local TextToDisplay=StringGSub(StringGSub(KeyString,"KeyCode.",""),"UserInputType.","") or "None"
                TextToDisplay=StringGSub(StringGSub(KeyString,"KeyCode.",""),"UserInputType.","")
                Keybind.Value=TextToDisplay
                Items["Text"].Instance.Text=TextToDisplay
                if Data.Callback then 
                    Library:SafeCall(Data.Callback,Keybind.Toggled) 
                end
            end
            Keybind.Picking=false
            Items["Text"]:Tween(nil,{TextColor3=Library.Theme.Text})
            Items["Text"]:ChangeItemTheme({TextColor3="Text"})
            Items["Text"].Instance.Size=UDim2New(0,Items["Text"].Instance.TextBounds.X,1,1)
            Update()
        end
        
        function Keybind:SetMode(Mode)
            for Index,Value in pairs(Modes) do
                if Index==Mode then 
                    Value:Tween(nil,{TextColor3=Library.Theme.Accent})
                    Value:ChangeItemTheme({TextColor3="Accent"})
                else 
                    Value:Tween(nil,{TextColor3=Library.Theme.Text})
                    Value:ChangeItemTheme({TextColor3="Text"})
                end
            end
            Keybind.Toggled=Keybind.Mode=="Always" and true or false
            Library.Flags[Data.Flag]={Mode=Keybind.Mode,Key=Keybind.Key,Toggled=Keybind.Toggled}
            if Data.Callback then 
                Library:SafeCall(Data.Callback,Keybind.Toggled) 
            end
            Update()
        end
        
        function Keybind:Press(Bool)
            if Keybind.Mode=="Toggle" then 
                Keybind.Toggled=not Keybind.Toggled
            elseif Keybind.Mode=="Hold" then 
                Keybind.Toggled=Bool
            elseif Keybind.Mode=="Always" then 
                Keybind.Toggled=true 
            end
            Library.Flags[Data.Flag]={Mode=Keybind.Mode,Key=Keybind.Key,Toggled=Keybind.Toggled}
            if Data.Callback then 
                Library:SafeCall(Data.Callback,Keybind.Toggled) 
            end
            Update()
        end
        
        Items["KeyButton"]:Connect("MouseButton1Click",function()
            if Keybind.Picking then return end
            Keybind.Picking=true
            Items["Text"]:Tween(nil,{TextColor3=Library.Theme.Accent})
            Items["Text"]:ChangeItemTheme({TextColor3="Accent"})
            local InputBegan
            InputBegan=UserInputService.InputBegan:Connect(function(Input)
                if Input.UserInputType==Enum.UserInputType.Keyboard then 
                    Keybind:Set(Input.KeyCode)
                else 
                    Keybind:Set(Input.UserInputType) 
                end
                InputBegan:Disconnect()
                InputBegan=nil
            end)
        end)
        
        Items["KeyButton"]:Connect("MouseButton2Down",function() 
            Keybind:SetOpen(not Keybind.IsOpen) 
        end)
        
        Library:Connect(UserInputService.InputBegan,function(Input)
            if tostring(Input.KeyCode)==Keybind.Key or tostring(Input.UserInputType)==Keybind.Key then
                if Keybind.Mode=="Toggle" then 
                    Keybind:Press()
                elseif Keybind.Mode=="Hold" then 
                    Keybind:Press(true) 
                end
            end
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then
                if Library:IsMouseOverFrame(Items["Window"]) then return end
                if Debounce then return end
                Keybind:SetOpen(false)
            end
        end)
        
        Library:Connect(UserInputService.InputEnded,function(Input)
            if tostring(Input.KeyCode)==Keybind.Key or tostring(Input.UserInputType)==Keybind.Key then
                if Keybind.Mode=="Hold" then 
                    Keybind:Press(false) 
                end
            end
        end)
        
        Items["Toggle"]:Connect("MouseButton1Down",function() 
            Keybind.Mode="Toggle"
            Keybind:SetMode("Toggle") 
        end)
        Items["Always"]:Connect("MouseButton1Down",function() 
            Keybind.Mode="Always"
            Keybind:SetMode("Always") 
        end)
        Items["Hold"]:Connect("MouseButton1Down",function() 
            Keybind.Mode="Hold"
            Keybind:SetMode("Hold") 
        end)
        
        if Data.Default then 
            Keybind:Set({Key=Data.Default,Mode=Data.Mode or "Toggle"}) 
        end
        Library.SetFlags[Data.Flag]=function(Value) 
            Keybind:Set(Value) 
        end
        return Keybind
    end

    Library.Window = function(self,Data)
        Data=Data or {}
        local Window={Name=Data.Name or Data.name or "Window",Size=Data.Size or Data.size or UDim2New(0,500,0,400),FadeSpeed=Data.FadeSpeed or Data.fadespeed or 0.25,Pages={},SubPages={},Elements={},IsOpen=true}
        local Items={}
        Items["MainFrame"]=Instances:Create("Frame",{Parent=Library.Holder.Instance,AnchorPoint=Vector2New(0,0),Name="\0",Position=UDim2New(0,0,0,0),BorderColor3=FromRGB(10,10,10),Size=Window.Size,BorderSizePixel=2,BackgroundColor3=FromRGB(15,15,20)})
        Items["MainFrame"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Items["MainFrame"].Instance.Position=UDim2New(0,100,0,100)
        Items["MainFrame"]:MakeDraggable()
        Items["MainFrame"]:MakeResizeable(Vector2New(Window.Size.X.Offset,Window.Size.Y.Offset),Vector2New(9999,9999))
        Items["AccentBorder"]=Instances:Create("UIStroke",{Parent=Items["MainFrame"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(235,157,255)})
        Items["AccentBorder"]:AddToTheme({Color="Accent"})
        Items["Title"]=Instances:Create("TextLabel",{Parent=Items["MainFrame"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Window.Name,Name="\0",Size=UDim2New(1,0,0,15),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2New(0,6,0,1),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Title"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Title"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["Inline"]=Instances:Create("Frame",{Parent=Items["MainFrame"].Instance,Name="\0",Position=UDim2New(0,7,0,20),BorderColor3=FromRGB(27,27,32),Size=UDim2New(1,-14,1,-27),BorderSizePixel=2,BackgroundColor3=FromRGB(20,20,25)})
        Items["Inline"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Outline"})
        Instances:Create("UIStroke",{Parent=Items["Inline"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Library.Theme.Border,Name="\0"}):AddToTheme({Color="Border"})
        Items["Pages"]=Instances:Create("Frame",{Parent=Items["Inline"].Instance,Name="\0",BackgroundTransparency=1,Position=UDim2New(0,7,0,7),BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,-14,0,19),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Instances:Create("UIListLayout",{Parent=Items["Pages"].Instance,FillDirection=Enum.FillDirection.Horizontal,HorizontalFlex=Enum.UIFlexAlignment.Fill,Padding=UDimNew(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        Items["Content"]=Instances:Create("Frame",{Parent=Items["Inline"].Instance,Name="\0",Position=UDim2New(0,7,0,26),BorderColor3=FromRGB(10,10,10),Size=UDim2New(1,-14,1,-33),BorderSizePixel=2,BackgroundColor3=FromRGB(15,15,20)})
        Items["Content"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["Content"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Library.Theme.Outline,Name="\0"}):AddToTheme({Color="Outline"})
        local Debounce=false

        function Window:SetOpen(Bool)
            if Debounce then return end
            Window.IsOpen=Bool
            Debounce=true
            if Bool then 
                Items["MainFrame"].Instance.Visible=true
                applyBlur()
                if ParticleSettings.Enabled then startParticleSystem() end
            else
                applyBlur(0)
                stopParticleSystem()
            end
            local Descendants=Items["MainFrame"].Instance:GetDescendants()
            TableInsert(Descendants,Items["MainFrame"].Instance)
            local NewTween
            for _,Value in pairs(Descendants) do
                local ValueIndex=Library:GetTransparencyPropertyFromItem(Value)
                if not ValueIndex then continue end
                if type(ValueIndex)=="table" then 
                    for _,Property in pairs(ValueIndex) do 
                        NewTween=Library:FadeItem(Value,Property,Bool,Window.FadeSpeed) 
                    end
                else 
                    NewTween=Library:FadeItem(Value,ValueIndex,Bool,Window.FadeSpeed) 
                end
            end
            Library:Connect(NewTween.Tween.Completed,function() 
                Debounce=false
                Items["MainFrame"].Instance.Visible=Bool 
            end)
        end
        
        Library:Connect(UserInputService.InputBegan,function(Input)
            if tostring(Input.KeyCode)==Library.MenuKeybind or tostring(Input.UserInputType)==Library.MenuKeybind then
                Window:SetOpen(not Window.IsOpen)
            end
        end)
        
        Window.Elements=Items
        return setmetatable(Window,Library)
    end

    function Library.Page(self,Data)
        Data=Data or {}
        local Page={Window=self,Name=Data.Name or Data.name or "Page",Columns=Data.Columns or Data.columns or 2,HasSubtabs=Data.Subtabs or Data.subtabs or false,Active=false,ColumnsData={},Elements={}}
        local Items={}
        Items["Inactive"]=Instances:Create("TextButton",{Parent=Page.Window.Elements["Pages"].Instance,FontFace=Library.Font,TextColor3=FromRGB(0,0,0),BorderColor3=FromRGB(10,10,10),Text="",AutoButtonColor=false,Name="\0",Size=UDim2New(1,0,1,0),BorderSizePixel=2,TextSize=14,BackgroundColor3=FromRGB(30,30,35)})
        Items["Inactive"]:AddToTheme({BackgroundColor3="Page Background",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["Inactive"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Library.Theme.Outline,Name="\0"}):AddToTheme({Color="Outline"})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["Inactive"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),TextTransparency=0.48,Text=Page.Name,Name="\0",Size=UDim2New(1,0,1,0),BackgroundTransparency=1,Position=UDim2New(0,0,0,-1),BorderSizePixel=0,BorderColor3=FromRGB(0,0,0),TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["Hide"]=Instances:Create("Frame",{Parent=Items["Inactive"].Instance,Visible=false,BorderColor3=FromRGB(0,0,0),AnchorPoint=Vector2New(0,1),Name="\0",Position=UDim2New(0,0,1,0),Size=UDim2New(1,0,0,3),ZIndex=2,BorderSizePixel=0,BackgroundColor3=FromRGB(15,15,20)})
        Items["Hide"]:AddToTheme({BackgroundColor3="Background"})
        Items["MiscPixel1"]=Instances:Create("Frame",{Parent=Items["Hide"].Instance,Size=UDim2New(0,1,0,1),Name="\0",Position=UDim2New(0,-1,0,1),BorderColor3=FromRGB(0,0,0),ZIndex=2,BorderSizePixel=0,BackgroundColor3=FromRGB(27,27,32)})
        Items["MiscPixel1"]:AddToTheme({BackgroundColor3="Outline"})
        Items["MiscPixel2"]=Instances:Create("Frame",{Parent=Items["Hide"].Instance,BorderColor3=FromRGB(0,0,0),AnchorPoint=Vector2New(1,0),Name="\0",Position=UDim2New(1,1,0,1),Size=UDim2New(0,1,0,1),ZIndex=2,BorderSizePixel=0,BackgroundColor3=FromRGB(27,27,32)})
        Items["MiscPixel2"]:AddToTheme({BackgroundColor3="Outline"})
        Instances:Create("UIGradient",{Parent=Items["Inactive"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(108,108,108))}})
        Items["Page"]=Instances:Create("Frame",{Parent=Page.Window.Elements["Content"].Instance,BackgroundTransparency=1,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,0,1,0),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255),Visible=false})
        
        if not Page.HasSubtabs then
            Instances:Create("UIListLayout",{Parent=Items["Page"].Instance,FillDirection=Enum.FillDirection.Horizontal,HorizontalFlex=Enum.UIFlexAlignment.Fill,SortOrder=Enum.SortOrder.LayoutOrder,VerticalFlex=Enum.UIFlexAlignment.Fill})
            for Index=1,Page.Columns do
                local NewColumn=Instances:Create("ScrollingFrame",{Parent=Items["Page"].Instance,ScrollBarImageColor3=FromRGB(235,157,255),Active=true,AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=1,Name="\0",BackgroundTransparency=1,Size=UDim2New(0,100,0,100),BackgroundColor3=FromRGB(255,255,255),BorderColor3=FromRGB(0,0,0),BorderSizePixel=0,BottomImage=Library:GetImage("Scrollbar"),MidImage=Library:GetImage("Scrollbar"),TopImage=Library:GetImage("Scrollbar"),CanvasSize=UDim2New(0,0,0,0)})
                NewColumn:AddToTheme({ScrollBarImageColor3="Accent"})
                Instances:Create("UIPadding",{Parent=NewColumn.Instance,PaddingTop=UDimNew(0,6),PaddingBottom=UDimNew(0,6),PaddingRight=UDimNew(0,6),PaddingLeft=UDimNew(0,6)})
                Instances:Create("UIListLayout",{Parent=NewColumn.Instance,Padding=UDimNew(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
                Page.ColumnsData[Index]=NewColumn
            end
        else
            Items["Columns"]=Instances:Create("Frame",{Parent=Items["Page"].Instance,Name="\0",Position=UDim2New(0,7,0,45),BorderColor3=FromRGB(10,10,10),Size=UDim2New(1,-14,1,-52),BorderSizePixel=2,BackgroundColor3=FromRGB(15,15,20)})
            Items["Columns"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
            Items["SubTabs"]=Instances:Create("Frame",{Parent=Items["Page"].Instance,Name="\0",BackgroundTransparency=1,Position=UDim2New(0,7,0,7),BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,-14,0,35),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
            Instances:Create("UIListLayout",{Parent=Items["SubTabs"].Instance,FillDirection=Enum.FillDirection.Horizontal,HorizontalFlex=Enum.UIFlexAlignment.Fill,Padding=UDimNew(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        end
        
        local Debounce=false
        
        function Page:Turn(Bool)
            if Debounce then return end
            Page.Active=Bool
            Debounce=true
            if Bool then
                Items["Page"].Instance.Visible=true
                Items["Text"]:Tween(nil,{TextColor3=Library.Theme.Accent,TextTransparency=0})
                Items["Hide"].Instance.Visible=true
                Items["Text"]:ChangeItemTheme({TextColor3="Accent"})
            else 
                Items["Text"]:Tween(nil,{TextColor3=Library.Theme.Text,TextTransparency=0.5})
                Items["Hide"].Instance.Visible=false
                Items["Text"]:ChangeItemTheme({TextColor3="Text"})
            end
            local Descendants=Items["Page"].Instance:GetDescendants()
            TableInsert(Descendants,Items["Page"].Instance)
            local NewTween
            for _,Value in pairs(Descendants) do
                local ValueIndex=Library:GetTransparencyPropertyFromItem(Value)
                if not ValueIndex then continue end
                if type(ValueIndex)=="table" then 
                    for _,Property in pairs(ValueIndex) do 
                        NewTween=Library:FadeItem(Value,Property,Bool,Page.Window.FadeSpeed or 0.5) 
                    end
                else 
                    NewTween=Library:FadeItem(Value,ValueIndex,Bool,Page.Window.FadeSpeed or 0.5) 
                end
            end
            Library:Connect(NewTween.Tween.Completed,function() 
                Debounce=false
                Items["Page"].Instance.Visible=Bool 
            end)
        end
        
        Items["Inactive"]:Connect("MouseButton1Down",function()
            for _,Value in pairs(Page.Window.Pages) do 
                Value:Turn(Value==Page) 
            end
        end)
        
        if #Page.Window.Pages==0 then 
            Page:Turn(true) 
        end
        Page.Elements=Items
        TableInsert(Page.Window.Pages,Page)
        return setmetatable(Page,Library.Pages)
    end

    function Library.Pages.Section(self,Data)
        Data=Data or {}
        local Section={Window=self.Window,Page=self,Name=Data.Name or Data.name or "Section",Side=Data.Side or Data.side or 1,Elements={}}
        local Items={}
        Items["Section"]=Instances:Create("Frame",{Parent=Section.Page.ColumnsData[Section.Side].Instance,Name="\0",Size=UDim2New(1,0,0,25),BorderColor3=FromRGB(27,27,32),BorderSizePixel=2,AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=FromRGB(20,20,25)})
        Items["Section"]:AddToTheme({BackgroundColor3="Inline",BorderColor3="Outline"})
        Instances:Create("UIStroke",{Parent=Items["Section"].Instance,Color=FromRGB(10,10,10),Name="\0",ApplyStrokeMode=Enum.ApplyStrokeMode.Border}):AddToTheme({Color="Border"})
        Instances:Create("UIPadding",{Parent=Items["Section"].Instance,PaddingBottom=UDimNew(0,6)})
        Items["AccentLine"]=Instances:Create("Frame",{Parent=Items["Section"].Instance,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,0,0,2),BorderSizePixel=0,BackgroundColor3=FromRGB(235,157,255)})
        Items["AccentLine"]:AddToTheme({BackgroundColor3="Accent"})
        Instances:Create("UIGradient",{Parent=Items["AccentLine"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(65,65,65))}})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["Section"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Section.Name,Name="\0",Size=UDim2New(1,-12,0,15),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2New(0,4,0,2),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["Content"]=Instances:Create("Frame",{Parent=Items["Section"].Instance,Name="\0",BackgroundTransparency=1,Position=UDim2New(0,7,0,21),BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,-14,1,-20),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Instances:Create("UIListLayout",{Parent=Items["Content"].Instance,Padding=UDimNew(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        
        Section.Elements = Items
        Section.Label = function(self, Data)
            return Library.Sections.Label(self, Data)
        end
        Section.Divider = function(self)
            return Library.Sections.Divider(self)
        end
        Section.Button = function(self, Data)
            return Library.Sections.Button(self, Data)
        end
        Section.Dropdown = function(self, Data)
            return Library.Sections.Dropdown(self, Data)
        end
        Section.Textbox = function(self, Data)
            return Library.Sections.Textbox(self, Data)
        end
        Section.Slider = function(self, Data)
            return Library.Sections.Slider(self, Data)
        end
        Section.Listbox = function(self, Data)
            return Library.Sections.Listbox(self, Data)
        end
        Section.Toggle = function(self, Data)
            return Library.Sections.Toggle(self, Data)
        end
        
        return setmetatable(Section, Library.Sections)
    end

    function Library.Sections.Label(self,Data)
        Data=Data or {}
        local Label={Window=self.Window,Page=self.Page,Section=self,Name=Data.Name or Data.name,Alignment=Data.Alignment or Data.alignment or "Left",Count=0,Elements={}}
        local Items={}
        Items["Label"]=Instances:Create("Frame",{Parent=Label.Section.Elements["Content"].Instance,BackgroundTransparency=1,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,0,0,15),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["Label"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Label.Name,Name="\0",BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment[Label.Alignment],Size=UDim2New(1,0,1,0),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual,Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter}):AddToTheme({Color="Text Border"})
        
        Label.Elements = Items
        
        function Label:Colorpicker(Data)
            Data=Data or {}
            local ColorpickerData={Window=self.Window,Tab=self.Tab,Section=self.Section,Parent=Items["Label"],Name=Data.Name or Data.name or "Colorpicker",Flag=Data.Flag or Data.flag or Library:NextFlag(),Default=Data.Default or Data.default or Color3.fromRGB(255,255,255),Callback=Data.Callback or Data.callback or function()end,Alpha=Data.Alpha or Data.alpha or false,Count=Label.Count,FadeSpeed=self.Window.FadeSpeed}
            Label.Count=Label.Count + 1
            ColorpickerData.Count=Label.Count
            local Extension=Library:CreateColorpicker(ColorpickerData)
            return Extension
        end
        
        function Label:Keybind(Data)
            Data=Data or {}
            local KeybindData={Window=self.Window,Tab=self.Tab,Section=self.Section,Parent=Items["Label"],Name=Data.Name or Data.name or "Keybind",Flag=Data.Flag or Data.flag or Library:NextFlag(),Default=Data.Default ~= nil and Data.Default or Data.default,Mode=Data.Mode or Data.mode or "Toggle",Callback=Data.Callback or Data.callback or function()end}
            local Extension=Library:CreateKeybind(KeybindData)
            return Extension
        end
        
        return Label
    end

    function Library.Sections.Toggle(self,Data)
        Data=Data or {}
        local Toggle={Window=self.Window,Page=self.Page,Section=self,Name=Data.Name or Data.name or "Toggle",Flag=Data.Flag or Data.flag or Library:NextFlag(),Default=Data.Default or Data.default or false,Callback=Data.Callback or Data.callback or function()end,Value=false,Class="Toggle",Count=0}
        local Items={}
        Items["Toggle"]=Instances:Create("TextButton",{Parent=Toggle.Section.Elements["Content"].Instance,FontFace=Library.Font,TextColor3=FromRGB(0,0,0),BorderColor3=FromRGB(0,0,0),Text="",AutoButtonColor=false,BackgroundTransparency=1,Name="\0",Size=UDim2New(1,0,0,11),BorderSizePixel=0,TextSize=14,BackgroundColor3=FromRGB(255,255,255)})
        Items["Indicator"]=Instances:Create("Frame",{Parent=Items["Toggle"].Instance,Name="\0",BorderColor3=FromRGB(10,10,10),Size=UDim2New(0,10,0,10),BorderSizePixel=2,BackgroundColor3=FromRGB(33,33,36)})
        Items["Indicator"]:AddToTheme({BackgroundColor3="Element",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["Indicator"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIGradient",{Parent=Items["Indicator"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(100,100,100))}})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["Toggle"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),TextTransparency=0.48,Text=Toggle.Name,Name="\0",Size=UDim2New(1,0,1,0),Position=UDim2New(0,18,0,-1),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,BorderColor3=FromRGB(0,0,0),TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        
        Items["Toggle"]:OnHover(function() 
            if not Toggle.Value then 
                Items["Indicator"]:Tween(nil,{BackgroundColor3=Library.Theme["Hovered Element"]})
                Items["Indicator"]:ChangeItemTheme({BackgroundColor3="Hovered Element",BorderColor3="Border"}) 
            end 
        end)
        Items["Toggle"]:OnHoverLeave(function() 
            if not Toggle.Value then 
                Items["Indicator"]:Tween(nil,{BackgroundColor3=Library.Theme["Element"]})
                Items["Indicator"]:ChangeItemTheme({BackgroundColor3="Element",BorderColor3="Border"}) 
            end 
        end)
        
        function Toggle:Get() 
            return Toggle.Value 
        end
        
        function Toggle:Set(Bool)
            Toggle.Value = (Bool ~= nil and Bool) or (not Toggle.Value)
            Library.Flags[Toggle.Flag]=Toggle.Value
            if Toggle.Value then 
                Items["Indicator"]:ChangeItemTheme({BackgroundColor3="Accent"})
                Items["Indicator"]:Tween(nil,{BackgroundColor3=Library.Theme.Accent})
                Items["Text"]:Tween(nil,{TextTransparency=0})
            else 
                Items["Indicator"]:ChangeItemTheme({BackgroundColor3="Element"})
                Items["Indicator"]:Tween(nil,{BackgroundColor3=Library.Theme.Element})
                Items["Text"]:Tween(nil,{TextTransparency=0.48})
            end
            if Toggle.Callback then 
                Library:SafeCall(Toggle.Callback,Toggle.Value) 
            end
        end
        
        function Toggle:SetVisiblity(Bool) 
            Items["Toggle"].Instance.Visible=Bool 
        end
        
        function Toggle:Colorpicker(Data)
            Data=Data or {}
            local ColorpickerData={Window=self.Window,Tab=self.Tab,Section=self.Section,Parent=Items["Toggle"],Name=Data.Name or Data.name or "Colorpicker",Flag=Data.Flag or Data.flag or Library:NextFlag(),Default=Data.Default or Data.default or Color3.fromRGB(255,255,255),Callback=Data.Callback or Data.callback or function()end,Alpha=Data.Alpha or Data.alpha or false,Count=Toggle.Count,FadeSpeed=self.Window.FadeSpeed}
            Toggle.Count=Toggle.Count + 1
            ColorpickerData.Count=Toggle.Count
            local Extension=Library:CreateColorpicker(ColorpickerData)
            Library.Flags[ColorpickerData.Flag]=Extension
            return Extension
        end
        
        function Toggle:Keybind(Data)
            Data=Data or {}
            local KeybindData={Window=self.Window,Tab=self.Tab,Section=self.Section,Parent=Items["Toggle"],Name=Data.Name or Data.name or "Keybind",Flag=Data.Flag or Data.flag or Library:NextFlag(),Default=Data.Default ~= nil and Data.Default or Data.default,Mode=Data.Mode or Data.mode or "Toggle",Callback=Data.Callback or Data.callback or function()end}
            local Extension=Library:CreateKeybind(KeybindData)
            Library.Flags[KeybindData.Flag]=Extension
            return Extension
        end
        
        Items["Toggle"]:Connect("MouseButton1Down",function() 
            Toggle:Set() 
        end)
        
        if Toggle.Default then 
            Toggle:Set(Toggle.Default) 
        end
        Library.SetFlags[Toggle.Flag]=function(Value) 
            Toggle:Set(Value) 
        end
        return Toggle
    end

    function Library.Sections.Button(self,Data)
        Data=Data or {}
        local Button={Window=self.Window,Page=self.Page,Section=self,Name=Data.Name or Data.name,Callback=Data.Callback or Data.callback or function()end}
        local Items={}
        Items["Button"]=Instances:Create("TextButton",{Parent=Button.Section.Elements["Content"].Instance,BorderColor3=FromRGB(10,10,10),AutoButtonColor=false,Name="\0",Position=UDim2New(0,0,1,0),Size=UDim2New(1,0,0,17),Selectable=false,BorderSizePixel=2,BackgroundColor3=FromRGB(33,33,36)})
        Items["Button"]:AddToTheme({BackgroundColor3="Element",BorderColor3="Border"})
        Instances:Create("UIGradient",{Parent=Items["Button"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(100,100,100))}})
        Instances:Create("UIStroke",{Parent=Items["Button"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["Button"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Button.Name,Name="\0",Size=UDim2New(1,0,1,0),BackgroundTransparency=1,TextTruncate=Enum.TextTruncate.AtEnd,Position=UDim2New(0,0,0,-1),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Items["TextBorder"]=Instances:Create("UIStroke",{Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        
        Items["Button"]:OnHover(function() 
            Items["Button"]:Tween(nil,{BackgroundColor3=Library.Theme["Hovered Element"]})
            Items["Button"]:ChangeItemTheme({BackgroundColor3="Hovered Element",BorderColor3="Border"}) 
        end)
        Items["Button"]:OnHoverLeave(function() 
            Items["Button"]:Tween(nil,{BackgroundColor3=Library.Theme["Element"]})
            Items["Button"]:ChangeItemTheme({BackgroundColor3="Element",BorderColor3="Border"}) 
        end)
        
        function Button:Press()
            Library:SafeCall(Button.Callback)
            Items["Text"]:ChangeItemTheme({TextColor3="Accent"})
            Items["Button"]:ChangeItemTheme({BackgroundColor3="Accent"})
            Items["Text"]:Tween(nil,{TextColor3=Library.Theme.Accent})
            Items["Button"]:Tween(nil,{BackgroundColor3=Library.Theme.Accent})
            task.wait(0.1)
            Items["Text"]:ChangeItemTheme({TextColor3="Text"})
            Items["Button"]:ChangeItemTheme({BackgroundColor3="Element"})
            Items["Text"]:Tween(nil,{TextColor3=Library.Theme.Text})
            Items["Button"]:Tween(nil,{BackgroundColor3=Library.Theme.Element})
        end
        
        function Button:SetVisiblity(Bool) 
            Items["Button"].Instance.Visible=Bool 
        end
        
        Items["Button"]:Connect("MouseButton1Down",function() 
            Button:Press() 
        end)
        return Button
    end

    function Library.Sections.Divider(self)
        local Divider={Window=self.Window,Page=self.Page,Section=self}
        local Items={}
        Items["Divider"]=Instances:Create("Frame",{Parent=Divider.Section.Elements["Content"].Instance,BackgroundTransparency=1,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,0,0,10),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Items["RealDivider"]=Instances:Create("Frame",{Parent=Items["Divider"].Instance,AnchorPoint=Vector2New(0,0.5),Name="\0",Position=UDim2New(0,0,0.5,0),BorderColor3=FromRGB(10,10,10),Size=UDim2New(1,0,0,3),BorderSizePixel=2,BackgroundColor3=FromRGB(15,15,20)})
        Items["RealDivider"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["RealDivider"].Instance,Color=FromRGB(27,27,32),Name="\0",ApplyStrokeMode=Enum.ApplyStrokeMode.Border}):AddToTheme({Color="Outline"})
        
        function Divider:SetVisibility(Bool) 
            Items["Divider"].Instance.Visible=Bool 
        end
        return Divider
    end

    function Library.Sections.Dropdown(self,Data)
        Data=Data or {}
        local Dropdown={Window=self.Window,Page=self.Page,Section=self,Name=Data.Name or Data.name or "Dropdown",Flag=Data.Flag or Data.flag or Library:NextFlag(),Items=Data.Items or Data.items or{"One","Two","Three"},Default=Data.Default or Data.default or nil,Callback=Data.Callback or Data.callback or function()end,Multi=Data.Multi or Data.multi or false,Value={},IsOpen=false,Options={},Class="Dropdown"}
        local Items={}
        Items["Dropdown"]=Instances:Create("Frame",{Parent=Dropdown.Section.Elements["Content"].Instance,BackgroundTransparency=1,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,0,0,34),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["Dropdown"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Dropdown.Name,Name="\0",BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2New(1,0,0,13),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["RealDropdown"]=Instances:Create("Frame",{Parent=Items["Dropdown"].Instance,AnchorPoint=Vector2New(0,1),Name="\0",Position=UDim2New(0,0,1,0),BorderColor3=FromRGB(10,10,10),Size=UDim2New(1,0,0,17),BorderSizePixel=2,BackgroundColor3=FromRGB(33,33,36)})
        Items["RealDropdown"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Instances:Create("UIGradient",{Parent=Items["RealDropdown"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(100,100,100))}})
        Instances:Create("UIStroke",{Parent=Items["RealDropdown"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["Open"]=Instances:Create("TextButton",{Parent=Items["RealDropdown"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="+",AutoButtonColor=false,Name="\0",Size=UDim2New(1,0,1,0),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Right,Position=UDim2New(0,-4,0,-1),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Open"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Open"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["Value"]=Instances:Create("TextLabel",{Parent=Items["RealDropdown"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="--",Name="\0",Size=UDim2New(1,-25,1,0),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Position=UDim2New(0,5,0,-1),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Value"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Value"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["OptionHolder"]=Instances:Create("ScrollingFrame",{Parent=Items["Dropdown"].Instance,Visible=false,BorderColor3=FromRGB(10,10,10),Name="\0",Position=UDim2New(0,0,1,5),Size=UDim2New(1,0,0,0),BorderSizePixel=2,BackgroundColor3=FromRGB(20,20,25),ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y,AutomaticCanvasSize=Enum.AutomaticSize.Y,ClipsDescendants=true})
        Items["OptionHolder"]:AddToTheme({BackgroundColor3="Inline",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["OptionHolder"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIListLayout",{Parent=Items["OptionHolder"].Instance,SortOrder=Enum.SortOrder.LayoutOrder})
        Instances:Create("UIPadding",{Parent=Items["OptionHolder"].Instance,PaddingBottom=UDimNew(0,2)})
        
        Items["RealDropdown"]:OnHover(function() 
            Items["RealDropdown"]:Tween(nil,{BackgroundColor3=Library.Theme["Hovered Element"]})
            Items["RealDropdown"]:ChangeItemTheme({BackgroundColor3="Hovered Element",BorderColor3="Border"}) 
        end)
        Items["RealDropdown"]:OnHoverLeave(function() 
            Items["RealDropdown"]:Tween(nil,{BackgroundColor3=Library.Theme["Background"]})
            Items["RealDropdown"]:ChangeItemTheme({BackgroundColor3="Background",BorderColor3="Border"}) 
        end)
        
        function Dropdown:Set(Option)
            if Dropdown.Multi then
                if type(Option)~="table" then return end
                Dropdown.Value=Option
                for _,Value in pairs(Option) do 
                    local OptionData=Dropdown.Options[Value]
                    if not OptionData then return end
                    OptionData.Selected=true
                    OptionData:Toggle("Active") 
                end
                Library.Flags[Dropdown.Flag]=Dropdown.Value
                Items["Value"].Instance.Text=TableConcat(Option,", ")
            else
                if not Dropdown.Options[Option] then return end
                local OptionData=Dropdown.Options[Option]
                Dropdown.Value=OptionData.Name
                OptionData.Selected=true
                OptionData:Toggle("Active")
                for _,Value in pairs(Dropdown.Options) do 
                    if Value~=OptionData then 
                        Value.Selected=false
                        Value:Toggle("Inactive") 
                    end 
                end
                Library.Flags[Dropdown.Flag]=Dropdown.Value
                Items["Value"].Instance.Text=Option
            end
            if Dropdown.Callback then 
                Library:SafeCall(Dropdown.Callback,Option) 
            end
        end
        
        function Dropdown:Get() 
            return Dropdown.Value 
        end
        
        function Dropdown:SetVisibility(Bool) 
            Items["Dropdown"].Instance.Visible=Bool 
        end
        
        function Dropdown:Add(Option)
            local OptionButton=Instances:Create("TextButton",{Parent=Items["OptionHolder"].Instance,FontFace=Library.Font,TextColor3=FromRGB(0,0,0),BorderColor3=FromRGB(0,0,0),Text="",AutoButtonColor=false,Name="\0",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2New(1,0,0,15),ZIndex=5,TextSize=14,BackgroundColor3=FromRGB(255,255,255)})
            local OptionText=Instances:Create("TextLabel",{Parent=OptionButton.Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),TextTransparency=0.48,Text=Option,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,-5,1,0),Position=UDim2New(0,5,0,0),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,ZIndex=5,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
            OptionText:AddToTheme({TextColor3="Text"})
            Instances:Create("UIStroke",{Parent=OptionText.Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
            local OptionData={Selected=false,Name=Option,Text=OptionText,Button=OptionButton}
            
            function OptionData:Toggle(State) 
                if State=="Active" then 
                    OptionData.Text:ChangeItemTheme({TextColor3="Accent"})
                    OptionData.Text:Tween(nil,{TextColor3=Library.Theme.Accent,TextTransparency=0})
                else 
                    OptionData.Text:ChangeItemTheme({TextColor3="Text"})
                    OptionData.Text:Tween(nil,{TextColor3=Library.Theme.Text,TextTransparency=0.48})
                end 
            end
            
            function OptionData:Set()
                OptionData.Selected=not OptionData.Selected
                if Dropdown.Multi then
                    local Index=TableFind(Dropdown.Value,OptionData.Name)
                    if Index then 
                        TableRemove(Dropdown.Value,Index) 
                    else 
                        TableInsert(Dropdown.Value,OptionData.Name) 
                    end
                    Library.Flags[Dropdown.Flag]=Dropdown.Value
                    OptionData:Toggle(Index and "Inactive" or "Active")
                    Items["Value"].Instance.Text=#Dropdown.Value>0 and TableConcat(Dropdown.Value,", ") or "--"
                else
                    if OptionData.Selected then
                        Dropdown.Value=OptionData.Name
                        Library.Flags[Dropdown.Flag]=Dropdown.Value
                        OptionData:Toggle("Active")
                        Items["Value"].Instance.Text=OptionData.Name
                        for _,Value in pairs(Dropdown.Options) do 
                            if Value~=OptionData then 
                                Value.Selected=false
                                Value:Toggle("Inactive") 
                            end 
                        end
                    else 
                        Dropdown.Value=(nil :: any)
                        OptionData:Toggle("Inactive")
                        Items["Value"].Instance.Text="--" 
                    end
                end
                if Dropdown.Callback then 
                    Library:SafeCall(Dropdown.Callback,Dropdown.Value) 
                end
            end
            
            OptionButton:Connect("MouseButton1Down",function() 
                OptionData:Set() 
            end)
            Dropdown.Options[Option]=OptionData
            return OptionData
        end
        
        function Dropdown:Remove(Option) 
            if Dropdown.Options[Option] then 
                Dropdown.Options[Option].Button:Clean() 
            end 
        end
        
        function Dropdown:Refresh(List) 
            for _,Value in pairs(Dropdown.Options) do 
                Dropdown:Remove(Value.Name) 
            end
            Dropdown.Options = {}
            for _,Value in pairs(List) do 
                Dropdown:Add(Value) 
            end 
        end
        
        local Debounce=false
        
        function Dropdown:SetOpen(Bool)
            if Debounce then return end
            Dropdown.IsOpen=Bool
            Debounce=true
            if Bool then 
                Items["OptionHolder"].Instance.Visible=true
                Items["OptionHolder"].Instance.ZIndex=15
                Items["Open"].Instance.Text="-"
                Items["Open"].Instance.Position=UDim2New(0,-5,0,-1)
            else 
                Items["Open"].Instance.Text="+"
                Items["Open"].Instance.Position=UDim2New(0,-4,0,-1)
            end
            local Descendants=Items["OptionHolder"].Instance:GetDescendants()
            TableInsert(Descendants,Items["OptionHolder"].Instance)
            local NewTween
            for _,Value in pairs(Descendants) do
                local ValueIndex=Library:GetTransparencyPropertyFromItem(Value)
                if not ValueIndex then continue end
                if not StringFind(Value.ClassName,"UI") then 
                    Value.ZIndex=Bool and 15 or 1 
                end
                if type(ValueIndex)=="table" then 
                    for _,Property in pairs(ValueIndex) do 
                        NewTween=Library:FadeItem(Value,Property,Bool,Dropdown.Window.FadeSpeed) 
                    end
                else 
                    NewTween=Library:FadeItem(Value,ValueIndex,Bool,Dropdown.Window.FadeSpeed) 
                end
            end
            Library:Connect(NewTween.Tween.Completed,function() 
                Debounce=false
                Items["OptionHolder"].Instance.Visible=Bool
                Items["OptionHolder"].Instance.ZIndex=Bool and 15 or 1 
            end)
        end
        
        for _,Value in pairs(Dropdown.Items) do 
            Dropdown:Add(Value) 
        end
        local optionCount = #Dropdown.Items
        local maxHeight = math.min(optionCount * 17 + 4, 200)
        Items["OptionHolder"].Instance.Size = UDim2New(1, 0, 0, maxHeight)
        
        Items["Open"]:Connect("MouseButton1Down",function() 
            Dropdown:SetOpen(not Dropdown.IsOpen) 
        end)
        
        if Dropdown.Default then 
            Dropdown:Set(Dropdown.Default) 
        end
        Library.SetFlags[Dropdown.Flag]=function(Value) 
            Dropdown:Set(Value) 
        end
        return Dropdown
    end

    function Library.Sections.Textbox(self,Data)
        Data=Data or {}
        local Textbox={Window=self.Window,Tab=self.Tab,Section=self,Name=Data.Name or Data.name or "Textbox",Flag=Data.Flag or Data.flag or Library:NextFlag(),Placeholder=Data.Placeholder or Data.placeholder or "...",Default=Data.Default or Data.default or "",Callback=Data.Callback or Data.callback or function()end,Value="",Class="Textbox"}
        local Items={}
        Items["Textbox"]=Instances:Create("Frame",{Parent=Textbox.Section.Elements["Content"].Instance,BackgroundTransparency=1,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,0,0,34),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["Textbox"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Textbox.Name,Name="\0",BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2New(1,0,0,13),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["Background"]=Instances:Create("Frame",{Parent=Items["Textbox"].Instance,AnchorPoint=Vector2New(0,1),Name="\0",Position=UDim2New(0,0,1,0),BorderColor3=FromRGB(10,10,10),Size=UDim2New(1,0,0,17),BorderSizePixel=2,BackgroundColor3=FromRGB(33,33,36)})
        Items["Background"]:AddToTheme({BackgroundColor3="Element",BorderColor3="Border"})
        Instances:Create("UIGradient",{Parent=Items["Background"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(100,100,100))}})
        Instances:Create("UIStroke",{Parent=Items["Background"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Items["Inline"]=Instances:Create("TextBox",{Parent=Items["Background"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="",Name="\0",Size=UDim2New(1,0,1,0),BorderSizePixel=0,ClearTextOnFocus=false,BackgroundTransparency=1,PlaceholderColor3=FromRGB(178,178,178),TextXAlignment=Enum.TextXAlignment.Left,PlaceholderText=Textbox.Placeholder,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Inline"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIPadding",{Parent=Items["Inline"].Instance,PaddingBottom=UDimNew(0,3),PaddingLeft=UDimNew(0,5)})
        Instances:Create("UIStroke",{Parent=Items["Inline"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        
        Items["Background"]:OnHover(function() 
            Items["Background"]:Tween(nil,{BackgroundColor3=Library.Theme["Hovered Element"]})
            Items["Background"]:ChangeItemTheme({BackgroundColor3="Hovered Element",BorderColor3="Border"}) 
        end)
        Items["Background"]:OnHoverLeave(function() 
            Items["Background"]:Tween(nil,{BackgroundColor3=Library.Theme["Element"]})
            Items["Background"]:ChangeItemTheme({BackgroundColor3="Element",BorderColor3="Border"}) 
        end)
        
        function Textbox:Get()
            return Items["Inline"] and Items["Inline"].Instance.Text or Textbox.Value
        end
        
        function Textbox:SetVisibility(Bool) 
            Items["Textbox"].Instance.Visible=Bool 
        end
        
        function Textbox:Set(Value)
            Textbox.Value=Value
            Items["Inline"].Instance.Text=Textbox.Value
            Items["Inline"]:Tween(nil,{TextColor3=Library.Theme.Text})
            Items["Inline"]:ChangeItemTheme({TextColor3="Text"})
            Library.Flags[Textbox.Flag]=Textbox.Value
            if Textbox.Callback then 
                Library:SafeCall(Textbox.Callback,Textbox.Value) 
            end
        end
        
        Items["Inline"]:Connect("Focused",function() 
            Items["Inline"]:ChangeItemTheme({TextColor3="Accent"})
            Items["Inline"]:Tween(nil,{TextColor3=Library.Theme.Accent}) 
        end)
        Items["Inline"]:Connect("FocusLost",function() 
            Items["Inline"]:ChangeItemTheme({TextColor3="Text"})
            Items["Inline"]:Tween(nil,{TextColor3=Library.Theme.Text})
            Textbox:Set(Items["Inline"].Instance.Text) 
        end)
        
        if Textbox.Default then 
            Textbox:Set(Textbox.Default) 
        end
        Library.SetFlags[Textbox.Flag]=function(Value) 
            Textbox:Set(Value) 
        end
        return Textbox
    end

    function Library.Sections.Listbox(self,Data)
        Data=Data or {}
        local Listbox={Window=self.Window,Page=self.Page,Section=self,Items=Data.Items or Data.items or {},Multi=Data.Multi or Data.multi or false,Default=Data.Default or Data.default or 1,Flag=Data.Flag or Data.flag or Library:NextFlag(),Callback=Data.Callback or Data.callback or function()end,Size=Data.Size or Data.size or 175,Value={},Options={},Class="Listbox"}
        local Items={}
        Items["Listbox"]=Instances:Create("Frame",{Parent=Listbox.Section.Elements["Content"].Instance,Name="\0",BackgroundTransparency=1,Size=UDim2New(1,0,0,Listbox.Size),BorderColor3=FromRGB(0,0,0),BorderSizePixel=0,AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=FromRGB(255,255,255)})
        Items["RealListbox"]=Instances:Create("ScrollingFrame",{Parent=Items["Listbox"].Instance,ScrollBarImageColor3=FromRGB(235,157,255),Active=true,AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=1,AnchorPoint=Vector2New(0,1),Size=UDim2New(1,0,1,0),Name="\0",Position=UDim2New(0,0,1,0),BackgroundColor3=FromRGB(15,15,20),BorderColor3=FromRGB(10,10,10),BorderSizePixel=2,CanvasSize=UDim2New(0,0,0,0)})
        Items["RealListbox"]:AddToTheme({ScrollBarImageColor3="Accent",BackgroundColor3="Background",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["RealListbox"].Instance,Color=FromRGB(27,27,32),Name="\0",ApplyStrokeMode=Enum.ApplyStrokeMode.Border}):AddToTheme({Color="Outline"})
        Instances:Create("UIListLayout",{Parent=Items["RealListbox"].Instance,SortOrder=Enum.SortOrder.LayoutOrder})
        Instances:Create("UIPadding",{Parent=Items["RealListbox"].Instance,PaddingBottom=UDimNew(0,5),PaddingTop=UDimNew(0,2)})
        
        function Listbox:Set(Option)
            if Listbox.Multi then
                if type(Option)~="table" then return end
                Listbox.Value=Option
                Library.Flags[Listbox.Flag]=Listbox.Value
                for _,Value in pairs(Option) do 
                    local OptionData=Listbox.Options[Value]
                    if not OptionData then return end
                    OptionData.Selected=true
                    OptionData:Toggle("Active") 
                end
            else
                if not Listbox.Options[Option] then return end
                local OptionData=Listbox.Options[Option]
                Listbox.Value=OptionData.Name
                Library.Flags[Listbox.Flag]=Listbox.Value
                OptionData.Selected=true
                OptionData:Toggle("Active")
                for _,Value in pairs(Listbox.Options) do 
                    if Value~=OptionData then 
                        Value.Selected=false
                        Value:Toggle("Inactive") 
                    end 
                end
            end
            if Listbox.Callback then 
                Library:SafeCall(Listbox.Callback,Option) 
            end
        end
        
        function Listbox:Get() 
            return Listbox.Value 
        end
        
        function Listbox:SetVisibility(Bool) 
            Items["Listbox"].Instance.Visible=Bool 
        end
        
        function Listbox:Remove(Option) 
            if Listbox.Options[Option] then 
                Listbox.Options[Option].Button:Clean() 
            end 
        end
        
        function Listbox:Refresh(List) 
            for _,Value in pairs(Listbox.Options) do 
                Listbox:Remove(Value.Name) 
            end
            Listbox.Options = {}
            for _,Value in pairs(List) do 
                Listbox:Add(Value) 
            end 
        end
        
        function Listbox:Add(Option)
            local OptionButton=Instances:Create("TextButton",{Parent=Items["RealListbox"].Instance,FontFace=Library.Font,TextColor3=FromRGB(0,0,0),BorderColor3=FromRGB(0,0,0),Text="",AutoButtonColor=false,Name="\0",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2New(1,0,0,15),ZIndex=5,TextSize=14,BackgroundColor3=FromRGB(255,255,255)})
            local OptionText=Instances:Create("TextLabel",{Parent=OptionButton.Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),TextTransparency=0.48,Text=Option,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,-5,1,0),Position=UDim2New(0,5,0,0),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Center,BorderSizePixel=0,ZIndex=5,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
            OptionText:AddToTheme({TextColor3="Text"})
            Instances:Create("UIStroke",{Parent=OptionText.Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
            local OptionData={Selected=false,Name=Option,Text=OptionText,Button=OptionButton}
            
            function OptionData:Toggle(State) 
                if State=="Active" then 
                    OptionData.Text:ChangeItemTheme({TextColor3="Accent"})
                    OptionData.Text:Tween(nil,{TextColor3=Library.Theme.Accent,TextTransparency=0})
                else 
                    OptionData.Text:ChangeItemTheme({TextColor3="Text"})
                    OptionData.Text:Tween(nil,{TextColor3=Library.Theme.Text,TextTransparency=0.48})
                end 
            end
            
            function OptionData:Set()
                OptionData.Selected=not OptionData.Selected
                if Listbox.Multi then
                    local Index=TableFind(Listbox.Value,OptionData.Name)
                    if Index then 
                        TableRemove(Listbox.Value,Index) 
                    else 
                        TableInsert(Listbox.Value,OptionData.Name) 
                    end
                    OptionData:Toggle(Index and "Inactive" or "Active")
                else
                    if OptionData.Selected then
                        Listbox.Value=OptionData.Name
                        OptionData:Toggle("Active")
                        for _,Value in pairs(Listbox.Options) do 
                            if Value~=OptionData then 
                                Value.Selected=false
                                Value:Toggle("Inactive") 
                            end 
                        end
                    else 
                        Listbox.Value=(nil :: any)
                        OptionData:Toggle("Inactive") 
                    end
                end
                if Listbox.Callback then 
                    Library:SafeCall(Listbox.Callback,Listbox.Value) 
                end
            end
            
            OptionButton:Connect("MouseButton1Down",function() 
                OptionData:Set() 
            end)
            Listbox.Options[Option]=OptionData
            return OptionData
        end
        
        for _,Value in pairs(Listbox.Items) do 
            Listbox:Add(Value) 
        end
        
        if Listbox.Default then 
            Listbox:Set(Listbox.Default) 
        end
        Library.SetFlags[Listbox.Flag]=function(Value) 
            Listbox:Set(Value) 
        end
        return Listbox
    end

    function Library.Sections.Slider(self,Data)
        Data=Data or {}
        local Slider={Window=self.Window,Page=self.Page,Section=self,Name=Data.Name or Data.name or "Slider",Flag=Data.Flag or Data.flag or Library:NextFlag(),Min=Data.Min or Data.min or 0,Default=Data.Default or Data.default or 0,Max=Data.Max or Data.max or 100,Suffix=Data.Suffix or Data.suffix or "",Decimals=Data.Decimals or Data.decimals or 1,Callback=Data.Callback or Data.callback or function()end,Compact=Data.Compact or Data.compact or false,Value=0,Sliding=false,Class="Slider"}
        local Items={}
        Items["Slider"]=Instances:Create("Frame",{Parent=Slider.Section.Elements["Content"].Instance,BackgroundTransparency=1,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,0,0,27),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]=Instances:Create("TextLabel",{Parent=Items["Slider"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Slider.Name,Name="\0",BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2New(1,0,0,13),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Text"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Text"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["RealSlider"]=Instances:Create("TextButton",{Parent=Items["Slider"].Instance,AnchorPoint=Vector2New(0,1),Name="\0",Position=UDim2New(0,0,1,0),BorderColor3=FromRGB(10,10,10),Text="",AutoButtonColor=false,Size=UDim2New(1,0,0,10),BorderSizePixel=2,BackgroundColor3=FromRGB(33,33,36)})
        Items["RealSlider"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["RealSlider"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIGradient",{Parent=Items["RealSlider"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(100,100,100))}})
        Items["Indicator"]=Instances:Create("Frame",{Parent=Items["RealSlider"].Instance,Name="\0",BorderColor3=FromRGB(0,0,0),Size=UDim2New(0.5,0,1,0),BorderSizePixel=0,BackgroundColor3=FromRGB(235,157,255)})
        Items["Indicator"]:AddToTheme({BackgroundColor3="Accent"})
        Instances:Create("UIGradient",{Parent=Items["Indicator"].Instance,Rotation=90,Color=RGBSequence{RGBSequenceKeypoint(0,FromRGB(255,255,255)),RGBSequenceKeypoint(1,FromRGB(100,100,100))}})
        Items["Value"]=Instances:Create("TextLabel",{Parent=Items["RealSlider"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="50/100s",Name="\0",BackgroundTransparency=1,Position=UDim2New(0,0,0,-1),Size=UDim2New(1,0,1,0),BorderSizePixel=0,TextSize=12,BackgroundColor3=FromRGB(255,255,255)})
        Items["Value"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Value"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        
        if Slider.Compact then
            Items["Value"]:Clean()
            Items["Value"]=nil
            Items["Slider"].Instance.Size=UDim2New(1,0,0,10)
            Items["Text"].Instance.Parent=Items["RealSlider"].Instance
            Items["Text"].Instance.Position=UDim2New(0,0,0,-2)
            Items["Text"].Instance.TextXAlignment=Enum.TextXAlignment.Center
        end
        
        Items["RealSlider"]:OnHover(function() 
            Items["RealSlider"]:Tween(nil,{BackgroundColor3=Library.Theme["Hovered Element"]})
            Items["RealSlider"]:ChangeItemTheme({BackgroundColor3="Hovered Element",BorderColor3="Border"}) 
        end)
        Items["RealSlider"]:OnHoverLeave(function() 
            Items["RealSlider"]:Tween(nil,{BackgroundColor3=Library.Theme["Background"]})
            Items["RealSlider"]:ChangeItemTheme({BackgroundColor3="Background",BorderColor3="Border"}) 
        end)
        
        function Slider:Set(Value)
            Slider.Value=MathClamp(Library:Round(Value,Slider.Decimals),Slider.Min,Slider.Max)
            Library.Flags[Slider.Flag]=Slider.Value
            if Slider.Compact then 
                Items["Text"].Instance.Text=string.format("%s: %s%s", Slider.Name, tostring(Slider.Value), Slider.Suffix)
            else 
                Items["Value"].Instance.Text=string.format("%s%s", tostring(Slider.Value), Slider.Suffix)
            end
            Items["Indicator"]:Tween(TweenInfo.new(0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2New((Slider.Value-Slider.Min)/(Slider.Max-Slider.Min),0,1,0)})
            if Slider.Callback then 
                Library:SafeCall(Slider.Callback,Slider.Value) 
            end
        end
        
        function Slider:Get() 
            return Slider.Value 
        end
        
        function Slider:SetVisibility(Bool) 
            Items["Slider"].Instance.Visible=Bool 
        end
        
        Items["RealSlider"]:Connect("MouseButton1Down",function()
            Slider.Sliding=true
            local MousePos=UserInputService:GetMouseLocation()
            local SizeX=(MousePos.X-Items["RealSlider"].Instance.AbsolutePosition.X)/Items["RealSlider"].Instance.AbsoluteSize.X
            Slider:Set(((Slider.Max-Slider.Min)*SizeX)+Slider.Min)
        end)
        
        Items["RealSlider"]:Connect("InputEnded",function(Input) 
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then 
                Slider.Sliding=false 
            end 
        end)
        
        Library:Connect(UserInputService.InputChanged,function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseMovement and Slider.Sliding then
                local MousePos=UserInputService:GetMouseLocation()
                local SizeX=(MousePos.X-Items["RealSlider"].Instance.AbsolutePosition.X)/Items["RealSlider"].Instance.AbsoluteSize.X
                Slider:Set(((Slider.Max-Slider.Min)*SizeX)+Slider.Min)
            end
        end)
        
        if Slider.Default then 
            Slider:Set(Slider.Default) 
        end
        Library.SetFlags[Slider.Flag]=function(Value) 
            Slider:Set(Value) 
        end
        return Slider
    end
end

getgenv().Library = Library

-- =========================================================
--  SNOW/RAIN PARTICLE SYSTEM (Heartbeat-driven, smooth motion)
-- =========================================================

local function createParticleFrame()
    local f = Instance.new("Frame")
    f.Name = "\0"
    f.BackgroundTransparency = 1
    f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    f.BorderSizePixel = 0
    f.Visible = false
    f.Parent = ParticleHolder
    local c = Instance.new("UICorner"); c.Parent = f
    local s = Instance.new("UIStroke"); s.Parent = f
    table.insert(ParticlePool, f)
    return f
end

local function emitParticle()
    if not ParticleSettings.Enabled then return end
    local view = Camera.ViewportSize
    if view.X <= 0 or view.Y <= 0 then return end

    local frame
    for _, v in ipairs(ParticlePool) do
        if not v.Visible then frame = v; break end
    end
    if not frame then frame = createParticleFrame() end

    local isSnow = ParticleSettings.Mode == "Snow"
    local p = {
        Frame = frame,
        X = math.random(0, view.X),
        Y = -math.random(20, 100),
        VY = 0, VX = 0,
        Life = 0, MaxLife = 1,
        Size = 1, Rot = 0, RotSpeed = 0,
        WobbleAmp = 0, WobbleFreq = 0, WobblePhase = 0,
        WindFactor = 1,
    }

    if isSnow then
        local sz = math.random(2, 14)
        p.Size = sz
        local speed = ParticleSettings.SnowSpeed
        p.VY = math.random(speed * 0.3, speed * 0.8)
        p.VX = math.random(-20, 20) + windGust * 25
        p.MaxLife = (view.Y + 150) / p.VY
        p.RotSpeed = math.random(-120, 120)
        p.WobbleAmp = math.random(15, 50)
        p.WobbleFreq = math.random(0.8, 3)
        p.WobblePhase = math.random() * math.pi * 2
        p.WindFactor = 0.5 + math.random() * 0.5

        frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        frame.Size = UDim2.new(0, sz, 0, sz)
        local corner = frame:FindFirstChildOfClass("UICorner")
        if corner then corner.CornerRadius = UDim.new(0, sz / 2) end
        local stroke = frame:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = Color3.fromRGB(200, 225, 255)
            stroke.Thickness = math.clamp(sz * 0.08, 0.3, 1)
            stroke.Transparency = 0.4
        end
    else
        local w = math.random(1, 2)
        local h = math.random(6, 22)
        p.Size = h
        p.VY = math.random(350, 700)
        p.VX = math.random(-15, 15) + windGust * 35
        p.MaxLife = (view.Y + 100) / p.VY
        p.RotSpeed = 0
        p.WobbleAmp = 3; p.WobbleFreq = 0

        frame.BackgroundColor3 = Color3.fromRGB(90, 155, 255)
        frame.Size = UDim2.new(0, w, 0, h)
        local corner = frame:FindFirstChildOfClass("UICorner")
        if corner then corner.CornerRadius = UDim.new(0, 0) end
        local stroke = frame:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = Color3.fromRGB(150, 200, 255)
            stroke.Thickness = 0.2
            stroke.Transparency = 0.6
        end
    end

    frame.Position = UDim2.new(0, p.X, 0, p.Y)
    frame.BackgroundTransparency = 0
    frame.Rotation = 0
    frame.Visible = true
    table.insert(ActiveParticles, p)
end

function cleanupParticles()
    for _, p in ipairs(ActiveParticles) do
        if p.Frame then p.Frame:Destroy() end
    end
    ActiveParticles = {}
    for _, f in ipairs(ParticlePool) do f:Destroy() end
    ParticlePool = {}
end

function startParticleSystem()
    cleanupParticles()
    if not ParticleSettings.Enabled then return end
    local isSnow = ParticleSettings.Mode == "Snow"
    for i = 1, isSnow and 30 or 50 do createParticleFrame() end

    local lastSpawn = 0
    heartbeatTasks.Particles = function(dt)
        if not ParticleSettings.Enabled then heartbeatTasks.Particles = function() end; cleanupParticles(); return end

        -- Update wind gust
        windGust = windGust + (math.random() - 0.5) * dt * 2
        windGust = math.clamp(windGust, -1, 1)

        -- Spawn new particles
        lastSpawn = lastSpawn + dt
        local interval, count
        if ParticleSettings.Mode == "Snow" then
            interval = math.max(0.02, 0.08 - ParticleSettings.SnowSpeed * 0.0004)
            count = math.random(1, 2)
        else
            interval = 0.012
            count = math.random(2, 4)
        end
        while lastSpawn >= interval do
            lastSpawn = lastSpawn - interval
            for i = 1, count do emitParticle() end
        end

        -- Update active particles
        local i = 1
        while i <= #ActiveParticles do
            local p = ActiveParticles[i]
            p.Life = p.Life + dt
            if p.Life >= p.MaxLife then
                p.Frame.Visible = false
                p.Frame.BackgroundTransparency = 1
                p.Frame.Position = UDim2.new(0, -200, 0, -200)
                TableRemove(ActiveParticles, i)
            else
                local t = p.Life / p.MaxLife
                local wobble = p.WobbleAmp > 0 and math.sin(p.Life * p.WobbleFreq + p.WobblePhase) * p.WobbleAmp * dt or 0
                local wind = windGust * 15 * p.WindFactor * dt
                p.X = p.X + p.VX * dt + wobble + wind
                p.Y = p.Y + p.VY * dt
                p.Rot = p.Rot + p.RotSpeed * dt

                p.Frame.Position = UDim2.new(0, p.X, 0, p.Y)
                p.Frame.Rotation = p.Rot
                p.Frame.BackgroundTransparency = t < 0.8 and t * 0.6 or math.min(1, 0.48 + (t - 0.8) * 2.6)
                i = i + 1
            end
        end
    end
end

function stopParticleSystem()
    heartbeatTasks.Particles = function() end
    cleanupParticles()
end

-- =========================================================
--  CREATE UI ELEMENTS (Project Bob - Combined Main)
-- =========================================================
local Watermark = Library:Watermark("Project Bob")
Watermark:SetVisibility(true)

local KeybindList = Library:KeybindList()
KeybindList:SetVisibility(true)

local Window = Library:Window({
    Name = "Project Bob",
    Size = UDim2.new(0, 600, 0, 450),
})

-- =========================================================
--  AIMBOT
-- =========================================================
Aimbot = {
    Enabled = false, TeamCheck = false, VisibilityCheck = false,
    TargetNPCs = false, TargetPart = "Closest",
    Smoothness = 0.5, FOV = 200, FOVEnabled = true,
    ShowFOVCircle = true, Method = "Camera",
    Prediction = 0, SelectedTarget = nil, FOVCircle = nil,
    aimKeyHeld = false,
    TargetParts = {"Closest","Head","UpperTorso","LowerTorso","HumanoidRootPart","RightUpperArm","LeftUpperArm"}
}

-- NPC cache (event-driven + periodic cleanup)
local npcModels = {}
local function refreshNPCCache()
    local pc = {}
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then pc[p.Character] = true end end
    local t = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and not pc[v] then
            local h = v:FindFirstChild("Humanoid")
            if h and h.Health > 0 then t[v] = true end
        end
    end
    npcModels = t
end
refreshNPCCache()
npcAddedConn = workspace.DescendantAdded:Connect(function(d)
    if not Aimbot.TargetNPCs then return end
    local m = d:IsA("Model") and d or d:FindFirstAncestorWhichIsA("Model")
    if not m or npcModels[m] then return end
    for _, p in ipairs(Players:GetPlayers()) do if p.Character == m then return end end
    local h = m:FindFirstChild("Humanoid")
    if h and h.Health > 0 then npcModels[m] = true end
end)
npcScanThread = task.spawn(function() while task.wait(2) do refreshNPCCache() end end)

local BodyPartsList = {"Head","UpperTorso","LowerTorso","HumanoidRootPart","RightUpperArm","LeftUpperArm","RightLowerArm","LeftLowerArm","RightUpperLeg","LeftUpperLeg","RightHand","LeftHand","RightFoot","LeftFoot"}

-- Universal silent aim: redirect game raycasts toward target via __namecall hook
local origRaycast = workspace.Raycast

local function silentAimRedirect(origin, direction)
    local t = Aimbot.SelectedTarget
    if not t or not t.Parent then return direction end
    local tp = t.Position + t.Velocity * Aimbot.Prediction
    if tp.X ~= tp.X then return direction end
    local len = typeof(direction) == "Vector3" and direction.Magnitude or 500
    return (tp - origin).Unit * math.max(len, 1)
end

local function shouldRedirect()
    if not (Aimbot and Aimbot.Enabled and Aimbot.Method == "Silent") then return false end
    if not Aimbot.SelectedTarget or not Aimbot.SelectedTarget.Parent then return false end
    local kd = Library and Library.Flags and Library.Flags["AimbotKeybind"]
    if not kd or not kd.Key or kd.Key == "" then return true end
    local m = kd.Mode or ""
    if m == "Always" then return true end
    if m == "Toggle" then return kd.Toggled or false end
    return Aimbot.aimKeyHeld or false
end

-- __namecall hook intercepts all workspace:Raycast/FindPartOnRay calls from the game
local oldNC = nil
local function hookCallback(self, ...)
    local m = getnamecallmethod()
    local args = {...}
    local isRaycast = m == "Raycast" or m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRayWithWhitelist"

    if not isRaycast then
        return oldNC(self, ...)
    end

    if m == "Raycast" then
        local origin, direction = args[1], args[2]
        if shouldRedirect() then
            local camPos = Camera.CFrame.Position
            if (origin - camPos).Magnitude > 1 then
                direction = silentAimRedirect(origin, direction)
            end
        end
        return oldNC(self, origin, direction, args[3])
    else
        local ray = (...)
        if ray then
            local origin, direction = ray.Origin, ray.Direction
            if shouldRedirect() then
                local camPos = Camera.CFrame.Position
                if (origin - camPos).Magnitude > 1 then
                    direction = silentAimRedirect(origin, direction)
                    return oldNC(self, Ray.new(origin, direction), select(2, ...))
                end
            end
        end
        return oldNC(self, ...)
    end
end
local ok, res = pcall(hookmetamethod, workspace, "__namecall", hookCallback)
if ok then
    oldNC = res
end

-- Visibility check (uses origRaycast directly to bypass the __namecall hook)
local function isTargetVisible(p)
    if not p then return false end
    local dir = p.Position - Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local c = LocalPlayer.Character
    params.FilterDescendantsInstances = c and {c} or {}
    local hit = origRaycast(workspace, Camera.CFrame.Position, dir, params)
    return not hit or hit.Instance:IsDescendantOf(p.Parent)
end

-- Best body part (named part, or closest to crosshair)
local function getBestTargetPart(char)
    local center = Camera.ViewportSize / 2
    if Aimbot.TargetPart ~= "Closest" then
        return char:FindFirstChild(Aimbot.TargetPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    local cd, bp = 999999, nil
    for _, n in ipairs(BodyPartsList) do
        local p = char:FindFirstChild(n); if not p then continue end
        local pp = p.Position + p.Velocity * Aimbot.Prediction
        local sp, os = Camera:WorldToViewportPoint(pp); if not os then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < cd then cd, bp = d, p end
    end
    return bp
end

-- Find closest target within FOV (players + NPCs)
local function getClosestTarget()
    local maxD = Aimbot.FOVEnabled and Aimbot.FOV or 999999
    local cd, ct = maxD, nil
    local center = Camera.ViewportSize / 2
    local function scan(char, skipVis)
        local tp = getBestTargetPart(char); if not tp then return end
        if Aimbot.VisibilityCheck and not skipVis and not isTargetVisible(tp) then return end
        local pp = tp.Position + tp.Velocity * Aimbot.Prediction
        local sp, os = Camera:WorldToViewportPoint(pp); if not os then return end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < cd then cd, ct = d, tp end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == LocalPlayer then continue end
        local c = pl.Character; if not c then continue end
        local h = c:FindFirstChild("Humanoid")
        if not h or h.Health <= 0 then continue end
        if Aimbot.TeamCheck and pl.Team and LocalPlayer.Team and pl.Team == LocalPlayer.Team then continue end
        scan(c)
    end
    if Aimbot.TargetNPCs then
        for v in pairs(npcModels) do
            if not v.Parent then continue end
            local h = v:FindFirstChild("Humanoid")
            if not h or h.Health <= 0 then continue end
            scan(v, true)
        end
    end
    return ct
end

-- Camera aimbot (smooth CFrame lerp)
local function applyCameraAimbot(tp, s)
    if not tp then return end
    local p = tp.Position + tp.Velocity * Aimbot.Prediction
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, p), s)
end

-- Mouse aimbot (relative movement)
local function applyMouseAimbot(tp, s)
    if not tp then return end
    local p = tp.Position + tp.Velocity * Aimbot.Prediction
    local sp = Camera:WorldToViewportPoint(p)
    local np = Vector2.new(sp.X, sp.Y):Lerp(Vector2.new(Mouse.X, Mouse.Y), s)
    local dx, dy = np.X - Mouse.X, np.Y - Mouse.Y
    if dx ~= 0 or dy ~= 0 then pcall(mousemoverel, dx, dy) end
end

-- Throttle: full scan every N heartbeats
local aimTick, AIM_INTERVAL = 0, 3

-- Aimbot heartbeat (targeting + camera/mouse aim)
heartbeatTasks.Aimbot = function()
    if not Aimbot.Enabled then return end
    if not Library or not Library.Flags then return end
    local kd = Library.Flags["AimbotKeybind"]
    local active = false
    if kd and kd.Key and kd.Key ~= "" then
        local m = kd.Mode or ""
        if m == "Always" then active = true
        elseif m == "Toggle" then active = kd.Toggled or false
        else active = Aimbot.aimKeyHeld end
    else active = true end
    if not active then Aimbot.SelectedTarget = nil; return end
    aimTick = aimTick + 1
    if aimTick >= AIM_INTERVAL then aimTick = 0; Aimbot.SelectedTarget = getClosestTarget() end
    local t = Aimbot.SelectedTarget; if not t then return end
    if Aimbot.VisibilityCheck and not isTargetVisible(t) then Aimbot.SelectedTarget = nil; return end
    if Aimbot.Method == "Camera" then applyCameraAimbot(t, Aimbot.Smoothness)
    elseif Aimbot.Method == "Mouse" then applyMouseAimbot(t, Aimbot.Smoothness) end
end

-- Silent aim override (direct RenderStepped connection)
if silentAimConn then silentAimConn:Disconnect(); silentAimConn = nil end
silentAimConn = RunService.RenderStepped:Connect(function()
    if not Aimbot.Enabled or Aimbot.Method ~= "Silent" then return end
    if not Library or not Library.Flags then return end
    local kd = Library.Flags["AimbotKeybind"]
    local active = false
    if kd and kd.Key and kd.Key ~= "" then
        local m = kd.Mode or ""
        if m == "Always" then active = true
        elseif m == "Toggle" then active = kd.Toggled or false
        else active = Aimbot.aimKeyHeld end
    else active = true end
    if not active then Aimbot.SelectedTarget = nil; return end
    local t = getClosestTarget()
    if not t then return end
    Aimbot.SelectedTarget = t
    local p = t.Position + t.Velocity * Aimbot.Prediction
    if p.X ~= p.X then return end
    Mouse.Hit = CFrame.new(p)
    Mouse.Target = t
    Mouse.TargetFilter = t.Parent
end)

-- FOV circle overlay
local function createFOVCircle()
    if Aimbot.FOVCircle then pcall(function() Aimbot.FOVCircle:Destroy() end); Aimbot.FOVCircle = nil end
    local c = Instance.new("Frame")
    c.Name = "AimbotFOV"; c.BackgroundTransparency = 1; c.BorderSizePixel = 0
    c.AnchorPoint = Vector2.new(0.5, 0.5)
    c.Size = UDim2.new(0, Aimbot.FOV * 2, 0, Aimbot.FOV * 2)
    c.Position = UDim2.new(0.5, 0, 0.5, 0)
    c.Parent = Library.Holder.Instance
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255, 255, 255); s.Thickness = 1; s.Transparency = 0.4; s.Parent = c
    Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
    Aimbot.FOVCircle = c
end
createFOVCircle()

-- Update FOV circle each frame
renderTasks.AimbotFOV = function()
    local c = Aimbot.FOVCircle; if not c then return end
    local show = Aimbot.Enabled and Aimbot.ShowFOVCircle and Aimbot.FOVEnabled
    c.Visible = show
    if show then local r = Aimbot.FOV; c.Size = UDim2.new(0, r * 2, 0, r * 2); c.Position = UDim2.new(0.5, 0, 0.5, 0) end
end

-- =========================================================
--  GUN MODS
-- =========================================================
local GunMods = {
    RapidFire = 1, RapidFireEnabled = false,
    NoSpread = 0, NoSpreadEnabled = false,
    NoRecoil = 0, NoRecoilEnabled = false,
    InstantReload = false, HeadExpander = false, HeadExpanderSize = 8,
}
local _wasHeadExpanded = false

local origToolVals = setmetatable({}, {__mode = "k"})
local function saveOrigVal(tool, k, v)
    if not origToolVals[tool] then origToolVals[tool] = {} end
    if origToolVals[tool][k] == nil then origToolVals[tool][k] = v end
    return origToolVals[tool][k]
end

local function applyGunModsToTool(tool)
    if not tool then return end
    pcall(function()
        do
            local m = GunMods.RapidFire
            if GunMods.RapidFireEnabled and m > 1 then
                for _, k in ipairs({"FireRate","RateOfFire","FireDelay","Cooldown","Firerate","FireFrequency","Rate","ShotDelay","FireCooldown","WeaponFireRate","ShotCooldown","FiringRate","FireSpeed","ShootDelay","WaitTime","AttackDelay"}) do
                    local s, v = pcall(function() return tool[k] end)
                    if s and type(v) == "number" and v > 0 then tool[k] = saveOrigVal(tool, k, v) / m end
                end
            end
        end
        do
            local p = GunMods.NoSpread / 100
            if GunMods.NoSpreadEnabled and p > 0 then
                for _, k in ipairs({"Spread","Accuracy","BulletSpread","Inaccuracy","ShotSpread","BulletAccuracy","HipSpread","AimSpread","GunSpread","Deviation","Cone","Randomness","Bloom","ShotgunSpread","BulletDeviation","HipfireSpread","SpreadMin","SpreadMax","BaseSpread","MaxSpread","MinSpread","Scatter","Dispersion","Noise","Wobble","Jitter","Angle","Inaccuracy","BulletInaccuracy","ShotInaccuracy"}) do
                    local s, v = pcall(function() return tool[k] end)
                    if s and type(v) == "number" then tool[k] = saveOrigVal(tool, k, v) * (1 - p) end
                end
            end
        end
        do
            local p = GunMods.NoRecoil / 100
            if GunMods.NoRecoilEnabled and p > 0 then
                for _, k in ipairs({"Recoil","RecoilMin","RecoilMax","RecoilOffset","GunRecoil","CameraShake","HRecoil","VRecoil","HorizontalRecoil","VerticalRecoil","RecoilPattern","RecoilForce","Kick","WeaponRecoil","RecoilReduction","Shake","BulletRecoil","FireRecoil","RecoilResetTime","RecoilStamina","BaseRecoil","Spray","Sway","RecoilRise","RecoilDrift","RecoilRecovery","AimKick","WeaponSway","ADSRecoil","RecoilReduce","RecoilReset","RecoilDelay","RecoilControl"}) do
                    local s, v = pcall(function() return tool[k] end)
                    if s and type(v) == "number" then tool[k] = saveOrigVal(tool, k, v) * (1 - p) end
                end
            end
        end
        if GunMods.InstantReload then
            for _, k in ipairs({"ReloadTime","ReloadLength","ReloadDuration","Reload","ReloadSpeed","ReloadDelay","Reload_Time"}) do
                local s, v = pcall(function() return tool[k] end)
                if s and type(v) == "number" then tool[k] = 0 end
            end
        end
    end)
    for _, desc in ipairs(tool:GetDescendants()) do
        pcall(function()
            if desc:IsA("NumberValue") then
                local n = desc.Name:lower()
                local m, sp, rc = GunMods.RapidFire, GunMods.NoSpread / 100, GunMods.NoRecoil / 100
                if GunMods.RapidFireEnabled and m > 1 and (n:find("rate") or n:find("fire") or n:find("cooldown") or n:find("delay") or n:find("speed") or n:find("rof") or n:find("fir") or n:find("reload") or n:find("ammo") or n:find("wait") or n:find("shot")) and not (n:find("ammo") or n:find("max")) then
                    local ov = saveOrigVal(desc, "_v", desc.Value)
                    desc.Value = ov > 0 and ov / m or 0
                end
                if GunMods.NoSpreadEnabled and sp > 0 and (n:find("spread") or n:find("acc") or n:find("bloom") or n:find("inacc") or n:find("cone") or n:find("random") or n:find("deviat") or n:find("hip") or n:find("aimspread") or n:find("scatter") or n:find("dispersion") or n:find("noise") or n:find("wobble") or n:find("jitter") or n:find("angle") or n:find("inaccuracy")) then
                    desc.Value = saveOrigVal(desc, "_v", desc.Value) * (1 - sp)
                end
                if GunMods.NoRecoilEnabled and rc > 0 and (n:find("recoil") or n:find("kick") or n:find("shake") or n:find("hrec") or n:find("vrec") or n:find("pattern") or n:find("force") or n:find("stamina") or n:find("spray") or n:find("sway") or n:find("rise") or n:find("drift") or n:find("reset") or n:find("recovery") or n:find("aimkick") or n:find("weaponsway") or n:find("adsrecoil") or n:find("recoilreduce")) then
                    desc.Value = saveOrigVal(desc, "_v", desc.Value) * (1 - rc)
                end
                if GunMods.InstantReload and (n:find("reload") or n:find("reloadtime") or n:find("reloadspeed")) then desc.Value = 0 end
            elseif desc:IsA("IntValue") then
                local n = desc.Name:lower()
                local m = GunMods.RapidFire
                if GunMods.RapidFireEnabled and m > 1 and (n:find("rate") or n:find("fire") or n:find("cooldown") or n:find("delay") or n:find("reload") or n:find("ammo") or n:find("max")) and not (n:find("ammo") or n:find("max")) then
                    local ov = saveOrigVal(desc, "_v", desc.Value)
                    desc.Value = ov > 0 and ov / m or 0
                end
                if GunMods.NoSpreadEnabled and GunMods.NoSpread > 0 and (n:find("spread") or n:find("acc") or n:find("bloom") or n:find("inacc") or n:find("cone") or n:find("scatter") or n:find("dispersion") or n:find("jitter") or n:find("angle")) then desc.Value = saveOrigVal(desc, "_v", desc.Value) * (1 - GunMods.NoSpread / 100) end
                if GunMods.NoRecoilEnabled and GunMods.NoRecoil > 0 and (n:find("recoil") or n:find("kick") or n:find("shake") or n:find("hrec") or n:find("vrec") or n:find("pattern") or n:find("force") or n:find("rise") or n:find("drift") or n:find("recovery")) then desc.Value = saveOrigVal(desc, "_v", desc.Value) * (1 - GunMods.NoRecoil / 100) end
                if GunMods.InstantReload and (n:find("reload") or n:find("reloadtime") or n:find("reloadspeed")) then desc.Value = 0 end
            end
        end)
    end
    pcall(function()
        for k, v in pairs(tool:GetAttributes()) do
            if type(v) == "number" then
                local n = k:lower()
                local m, sp, rc = GunMods.RapidFire, GunMods.NoSpread / 100, GunMods.NoRecoil / 100
                if GunMods.RapidFireEnabled and m > 1 and (n:find("rate") or n:find("fire") or n:find("cooldown") or n:find("delay") or n:find("reload") or n:find("ammo") or n:find("max")) and not (n:find("ammo") or n:find("max")) then
                    tool:SetAttribute(k, v > 0 and v / m or 0)
                end
                if GunMods.NoSpreadEnabled and sp > 0 and (n:find("spread") or n:find("acc") or n:find("bloom") or n:find("cone") or n:find("scatter") or n:find("dispersion") or n:find("jitter") or n:find("angle")) then tool:SetAttribute(k, v * (1 - sp)) end
                if GunMods.NoRecoilEnabled and rc > 0 and (n:find("recoil") or n:find("kick") or n:find("shake") or n:find("hrec") or n:find("vrec") or n:find("pattern") or n:find("force") or n:find("rise") or n:find("drift") or n:find("recovery")) then tool:SetAttribute(k, v * (1 - rc)) end
                if GunMods.InstantReload and (n:find("reload") or n:find("reloadtime") or n:find("reloadspeed")) then tool:SetAttribute(k, 0) end
            end
        end
    end)
end

local function refreshGunTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChildOfClass("PlayerBackpack")
        if bp then tool = bp:FindFirstChildOfClass("Tool") end
    end
    return tool
end

heartbeatTasks.GunMods = function()
    local hasMods = (GunMods.RapidFireEnabled and GunMods.RapidFire > 1) or (GunMods.NoSpreadEnabled and GunMods.NoSpread > 0) or (GunMods.NoRecoilEnabled and GunMods.NoRecoil > 0) or GunMods.InstantReload
    if hasMods then
        local tool = refreshGunTool()
        if tool then applyGunModsToTool(tool) end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == LocalPlayer then continue end
        if pl.Team and LocalPlayer.Team and pl.Team == LocalPlayer.Team then continue end
        local c = pl.Character; if not c then continue end
        local h = c:FindFirstChild("Humanoid"); if not h or h.Health <= 0 then continue end
        local head = c:FindFirstChild("Head")
        if head then
            if GunMods.HeadExpander then
                head.Size = Vector3.new(GunMods.HeadExpanderSize, GunMods.HeadExpanderSize, GunMods.HeadExpanderSize)
            elseif _wasHeadExpanded then
                head.Size = Vector3.new(2, 1, 1)
            end
        end
    end
    -- Also expand NPC heads
    if GunMods.HeadExpander then
        local npcChars = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then npcChars[p.Character] = true end
        end
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA("Model") and not npcChars[v] then
                local h = v:FindFirstChild("Humanoid")
                local head = v:FindFirstChild("Head")
                if h and head and h.Health > 0 then
                    head.Size = Vector3.new(GunMods.HeadExpanderSize, GunMods.HeadExpanderSize, GunMods.HeadExpanderSize)
                end
            end
        end
    elseif _wasHeadExpanded then
        local npcChars = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then npcChars[p.Character] = true end
        end
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA("Model") and not npcChars[v] then
                local h = v:FindFirstChild("Humanoid")
                local head = v:FindFirstChild("Head")
                if h and head and h.Health > 0 then
                    head.Size = Vector3.new(2, 1, 1)
                end
            end
        end
    end
    _wasHeadExpanded = GunMods.HeadExpander
end

-- Apply gun mods immediately on tool equip
local function setupGunModsForChar(char)
    if not char then return end
    if gunModsConn then gunModsConn:Disconnect(); gunModsConn = nil end
    gunModsConn = char.ChildAdded:Connect(function(c)
        if c:IsA("Tool") then
            task.wait()
            applyGunModsToTool(c)
        end
    end)
end
if LocalPlayer.Character then setupGunModsForChar(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait()
    setupGunModsForChar(char)
end)

-- Combat Page
local CombatPage = Library.Page(Window, { Name = "Combat", Columns = 2 })
do
    local s = Library.Pages.Section(CombatPage, { Name = "Aimbot", Side = 1 })
    local _tog = s:Toggle({ Name = "Enabled", Flag = "AimbotToggle", Default = false, Callback = function(st)
        Aimbot.Enabled = st; if not st then Aimbot.SelectedTarget = nil end
    end })
    _tog:Keybind({ Name = "Keybind", Flag = "AimbotKeybind", Mode = "Hold", Callback = function(st)
        local kd = Library.Flags["AimbotKeybind"]
        if kd then
            if kd.Mode == "Toggle" then Aimbot.Enabled = st; _tog:Set(st)
            elseif kd.Mode == "Always" then Aimbot.Enabled = true; _tog:Set(true)
            elseif kd.Mode == "Hold" then Aimbot.aimKeyHeld = st end
        end
    end })
    s:Dropdown({ Name = "Target Part", Flag = "AimbotTargetPart", Items = Aimbot.TargetParts, Default = "Head", Callback = function(v) if v then Aimbot.TargetPart = v end end })
    s:Dropdown({ Name = "Method", Flag = "AimbotMethod", Items = {"Camera","Mouse","Silent"}, Default = "Camera", Callback = function(v) if v then Aimbot.Method = v end end })
    s:Slider({ Name = "Smoothness", Flag = "AimbotSmoothness", Min = 0.1, Max = 1, Default = 0.5, Suffix = "", Decimals = 2, Callback = function(v) Aimbot.Smoothness = v end })
    s:Toggle({ Name = "FOV Limit", Flag = "AimbotFOVEnabled", Default = true, Callback = function(v) Aimbot.FOVEnabled = v end })
    s:Slider({ Name = "FOV", Flag = "AimbotFOV", Min = 10, Max = 500, Default = 200, Suffix = "px", Decimals = 0, Callback = function(v) Aimbot.FOV = v end })
    s:Toggle({ Name = "Show FOV Circle", Flag = "AimbotShowFOVCircle", Default = true, Callback = function(v) Aimbot.ShowFOVCircle = v end })
    s:Slider({ Name = "Prediction", Flag = "AimbotPrediction", Min = 0, Max = 1, Default = 0, Suffix = "", Decimals = 2, Callback = function(v) Aimbot.Prediction = v end })
    s:Toggle({ Name = "Team Check", Flag = "AimbotTeamCheck", Default = false, Callback = function(v) Aimbot.TeamCheck = v end })
    s:Toggle({ Name = "Visibility Check", Flag = "AimbotVisibilityCheck", Default = false, Callback = function(v) Aimbot.VisibilityCheck = v end })
    s:Toggle({ Name = "Aim NPCs", Flag = "AimbotTargetNPCs", Default = false, Callback = function(v) Aimbot.TargetNPCs = v end })

    local g = Library.Pages.Section(CombatPage, { Name = "Gun Mods", Side = 2 })
    g:Toggle({ Name = "Rapid Fire", Flag = "GunRapidFireToggle", Default = false, Callback = function(v) GunMods.RapidFireEnabled = v end })
    g:Slider({ Name = "Rapid Multiplier", Flag = "GunRapidFire", Min = 1, Max = 10, Default = 1, Suffix = "x", Decimals = 1, Callback = function(v) GunMods.RapidFire = v end })
    g:Toggle({ Name = "No Spread", Flag = "GunNoSpreadToggle", Default = false, Callback = function(v) GunMods.NoSpreadEnabled = v end })
    g:Slider({ Name = "Spread Reduction", Flag = "GunNoSpread", Min = 0, Max = 100, Default = 0, Suffix = "%", Decimals = 0, Callback = function(v) GunMods.NoSpread = v end })
    g:Toggle({ Name = "No Recoil", Flag = "GunNoRecoilToggle", Default = false, Callback = function(v) GunMods.NoRecoilEnabled = v end })
    g:Slider({ Name = "Recoil Reduction", Flag = "GunNoRecoil", Min = 0, Max = 100, Default = 0, Suffix = "%", Decimals = 0, Callback = function(v) GunMods.NoRecoil = v end })
    g:Toggle({ Name = "Instant Reload", Flag = "GunInstantReload", Default = false, Callback = function(v) GunMods.InstantReload = v end })
    g:Toggle({ Name = "Head Expander", Flag = "GunHeadExpander", Default = false, Callback = function(v) GunMods.HeadExpander = v end })
    g:Slider({ Name = "Head Expander Size", Flag = "GunHeadSize", Min = 2, Max = 20, Default = 8, Suffix = "", Decimals = 0, Callback = function(v) GunMods.HeadExpanderSize = v end })
end




-- ESP Library Module
do
    local screenGui = Instance.new('ScreenGui')
    screenGui.Name = "ESPLibrary"
    screenGui.Parent = CoreGui
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 100

    local ESPLibrary = {}

    ESPLibrary.Config = {
        Enabled = false, MaxDistance = 2000,
        Box = false, BoxFill = false, BoxThickness = 2, BoxFillTransparency = 0.5, BoxFillColor = Color3.fromRGB(0, 0, 0),
        Tracers = false, TracerThickness = 1, TracerOrigin = "Bottom",
        HeadDot = false,
        BoxColor = Color3.fromRGB(255, 255, 255),
        TracerColor = Color3.fromRGB(255, 255, 255),
        HeadDotColor = Color3.fromRGB(255, 0, 0),
        Chams = false, ChamsColor = Color3.fromRGB(0, 255, 255), ChamsTransparency = 0.5,
        ChamsOutline = false, ChamsOutlineColor = Color3.fromRGB(255, 255, 255), ChamsOutlineTransparency = 0,
        ChamsDepthMode = "AlwaysOnTop",
        ChamsTargets = false, ChamsPlayer = true, ChamsVM = false, ChamsMesh = false, ChamsWeapon = false, ChamsHead = false, ChamsAccessory = false,
        ChamsStyle = "Default",
        Skeleton = false, SkeletonColor = Color3.fromRGB(255, 255, 255),
        Healthbar = false, HealthbarText = false,
        HighHealth = Color3.fromRGB(0, 255, 0), MidHealth = Color3.fromRGB(255, 165, 0), LowHealth = Color3.fromRGB(255, 0, 0),
        Names = false, DistanceText = false, WeaponText = false, Flags = false,
        TextColor = Color3.fromRGB(255, 255, 255), FontSize = 12, TeamCheck = true, NPCs = false,
        BoxStyle = "Full", TextOutline = false, TextBackground = false,
    }

    local ChamsStyles = {
        Default   = { Color = Color3.fromRGB(0, 255, 255),   Outline = false, OutlineColor = Color3.fromRGB(255, 255, 255), OutlineTrans = 0, FillTrans = 0.5 },
        ForceField = { Color = Color3.fromRGB(0, 120, 255),  Outline = true,  OutlineColor = Color3.fromRGB(100, 180, 255), OutlineTrans = 0.3, FillTrans = 0.35 },
        Neon      = { Color = Color3.fromRGB(255, 255, 255), Outline = true,  OutlineColor = Color3.fromRGB(0, 255, 255),   OutlineTrans = 0, FillTrans = 0.15 },
        Ghost     = { Color = Color3.fromRGB(180, 180, 255), Outline = true,  OutlineColor = Color3.fromRGB(255, 255, 255), OutlineTrans = 0.2, FillTrans = 0.7 },
        XRay      = { Color = Color3.fromRGB(255, 100, 0),   Outline = false, OutlineColor = Color3.fromRGB(255, 200, 0),  OutlineTrans = 0, FillTrans = 0.4 },
        Heatmap   = { Color = Color3.fromRGB(255, 0, 0),     Outline = true,  OutlineColor = Color3.fromRGB(255, 255, 0),  OutlineTrans = 0.1, FillTrans = 0.3 },
        Rainbow   = { Color = Color3.fromRGB(255, 0, 255),   Outline = true,  OutlineColor = Color3.fromRGB(0, 255, 255),  OutlineTrans = 0, FillTrans = 0.4 },
    }

    local function getChamsStyle()
        local styleName = ESPLibrary.Config.ChamsStyle or "Default"
        return ChamsStyles[styleName] or ChamsStyles.Default
    end

    local function rainbowColor(t)
        local h = (t % 5) / 5
        return Color3.fromHSV(h, 1, 1)
    end

    local espCache = {}
    local npcCache = {}

    local function round(num, decimal)
        local mult = 10^(decimal or 1)
        return math.floor(num * mult + 0.5) / mult
    end

    local function getWeapon(character)
        if not character then return "None" end
        for _, model in ipairs(character:GetChildren()) do
            if model:IsA("Model") and model.Name ~= "Hair" and model.Name ~= "HolsterModel" and model.PrimaryPart then
                if model:FindFirstChild("Detail") or model:FindFirstChild("Main") or model:FindFirstChild("Handle") or
                   model:FindFirstChild("Attachments") or model:FindFirstChild("ArrowAttach") or model:FindFirstChild("Attach") then
                    return model.Name
                end
            end
        end
        return "None"
    end

    function ESPLibrary:CreateESP(player, character)
        self:RemoveESP(player)
        local humanoidRootPart = character:WaitForChild('HumanoidRootPart', 5)
        local humanoid = character:WaitForChild('Humanoid', 5)
        if not humanoidRootPart or not humanoid then return end
        local items = {}

        items.Main = Instance.new("Frame")
        items.Main.AnchorPoint = Vector2.new(0.5, 0.5)
        items.Main.Parent = screenGui
        items.Main.Size = UDim2.new(0, 150, 0, 250)
        items.Main.BorderSizePixel = 0
        items.Main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        items.Main.Visible = false

        items.BoxOutline = Instance.new("UIStroke")
        items.BoxOutline.Thickness = 2
        items.BoxOutline.LineJoinMode = Enum.LineJoinMode.Miter
        items.BoxOutline.Parent = items.Main
        items.BoxOutline.BorderOffset = UDim.new(0, -1)
        items.BoxOutline.Transparency = 0.5

        items.BoxAccent = Instance.new("UIStroke")
        items.BoxAccent.LineJoinMode = Enum.LineJoinMode.Miter
        items.BoxAccent.Color = ESPLibrary.Config.BoxColor
        items.BoxAccent.ZIndex = 2
        items.BoxAccent.Parent = items.Main

        -- Corner box frames (4 corners, each with 2 frame lines)
        items.BoxCorners = {}
        for _, data in ipairs({
            { "TL", UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0) },
            { "TR", nil, nil },
            { "BL", nil, nil },
            { "BR", nil, nil },
        }) do
            local h = Instance.new("Frame")
            h.BorderSizePixel = 0; h.BackgroundColor3 = ESPLibrary.Config.BoxColor; h.Visible = false; h.Parent = items.Main
            local v = Instance.new("Frame")
            v.BorderSizePixel = 0; v.BackgroundColor3 = ESPLibrary.Config.BoxColor; v.Visible = false; v.Parent = items.Main
            items.BoxCorners[data[1]] = { h = h, v = v }
        end

        items.Left = Instance.new("Frame")
        items.Left.Parent = items.Main
        items.Left.Size = UDim2.new(0, 0, 1, 4)
        items.Left.Position = UDim2.new(0, -4, 0, -2)
        items.Left.ZIndex = 2
        items.Left.BorderSizePixel = 0
        items.Left.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

        items.Healthbar = Instance.new("Frame")
        items.Healthbar.Parent = items.Left
        items.Healthbar.BackgroundTransparency = 0.5
        items.Healthbar.Size = UDim2.new(0, 4, 1, 0)
        items.Healthbar.BorderSizePixel = 0
        items.Healthbar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

        items.HealthbarAccent = Instance.new("Frame")
        items.HealthbarAccent.ClipsDescendants = true
        items.HealthbarAccent.LayoutOrder = -1
        items.HealthbarAccent.Parent = items.Healthbar
        items.HealthbarAccent.Position = UDim2.new(0, 1, 0, 1)
        items.HealthbarAccent.Size = UDim2.new(1, -2, 1, -2)
        items.HealthbarAccent.BorderSizePixel = 0
        items.HealthbarAccent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

        items.HealthbarGradient = Instance.new("UIGradient")
        items.HealthbarGradient.Rotation = 90
        items.HealthbarGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 179, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))})
        items.HealthbarGradient.Parent = items.HealthbarAccent

        items.HealthText = Instance.new("TextLabel")
        items.HealthText.TextSize = ESPLibrary.Config.FontSize
        items.HealthText.TextColor3 = Color3.fromRGB(0, 255, 0)
        items.HealthText.Text = "100"
        items.HealthText.BackgroundTransparency = 1
        items.HealthText.Size = UDim2.new(0, 0, 0, 0)
        items.HealthText.BorderSizePixel = 0
        items.HealthText.AutomaticSize = Enum.AutomaticSize.XY
        items.HealthText.Parent = items.Main

        items.Name = Instance.new("TextLabel")
        items.Name.TextSize = ESPLibrary.Config.FontSize
        items.Name.TextColor3 = Color3.fromRGB(255, 255, 255)
        items.Name.Text = player and player.Name or character.Name
        items.Name.BackgroundTransparency = 1
        items.Name.Size = UDim2.new(0, 0, 0, 0)
        items.Name.BorderSizePixel = 0
        items.Name.AutomaticSize = Enum.AutomaticSize.XY
        items.Name.Parent = items.Main
        local ns = Instance.new("UIStroke")
        ns.Color = Color3.fromRGB(0, 0, 0); ns.Thickness = 2; ns.Enabled = false
        ns.Parent = items.Name
        items.NameStroke = ns

        items.Distance = Instance.new("TextLabel")
        items.Distance.TextSize = ESPLibrary.Config.FontSize
        items.Distance.TextColor3 = Color3.fromRGB(255, 255, 255)
        items.Distance.Text = "100st"
        items.Distance.BackgroundTransparency = 1
        items.Distance.Size = UDim2.new(0, 0, 0, 0)
        items.Distance.BorderSizePixel = 0
        items.Distance.AutomaticSize = Enum.AutomaticSize.XY
        items.Distance.Parent = items.Main
        local ds = Instance.new("UIStroke")
        ds.Color = Color3.fromRGB(0, 0, 0); ds.Thickness = 2; ds.Enabled = false
        ds.Parent = items.Distance
        items.DistanceStroke = ds

        items.Weapon = Instance.new("TextLabel")
        items.Weapon.TextSize = ESPLibrary.Config.FontSize
        items.Weapon.TextColor3 = Color3.fromRGB(255, 255, 255)
        items.Weapon.Text = "none"
        items.Weapon.BackgroundTransparency = 1
        items.Weapon.Size = UDim2.new(0, 0, 0, 0)
        items.Weapon.BorderSizePixel = 0
        items.Weapon.AutomaticSize = Enum.AutomaticSize.XY
        items.Weapon.Parent = items.Main
        local ws = Instance.new("UIStroke")
        ws.Color = Color3.fromRGB(0, 0, 0); ws.Thickness = 2; ws.Enabled = false
        ws.Parent = items.Weapon
        items.WeaponStroke = ws

        items.Flags = Instance.new("TextLabel")
        items.Flags.TextSize = ESPLibrary.Config.FontSize
        items.Flags.TextColor3 = Color3.fromRGB(255, 255, 255)
        items.Flags.Text = ""
        items.Flags.BackgroundTransparency = 1
        items.Flags.Size = UDim2.new(0, 0, 0, 0)
        items.Flags.BorderSizePixel = 0
        items.Flags.AutomaticSize = Enum.AutomaticSize.XY
        items.Flags.RichText = true
        items.Flags.Parent = items.Main
        local fs = Instance.new("UIStroke")
        fs.Color = Color3.fromRGB(0, 0, 0); fs.Thickness = 2; fs.Enabled = false
        fs.Parent = items.Flags
        items.FlagsStroke = fs

        -- Tracer (line from screen bottom to player)
        items.Tracer = Instance.new("Frame")
        items.Tracer.BorderSizePixel = 0
        items.Tracer.AnchorPoint = Vector2.new(0, 0.5)
        items.Tracer.BackgroundColor3 = ESPLibrary.Config.TracerColor
        items.Tracer.Visible = false
        items.Tracer.Parent = screenGui

        -- Head Dot (circle)
        items.HeadDot = Instance.new("Frame")
        items.HeadDot.AnchorPoint = Vector2.new(0.5, 0.5)
        items.HeadDot.Size = UDim2.new(0, 8, 0, 8)
        items.HeadDot.BorderSizePixel = 0
        items.HeadDot.BackgroundColor3 = ESPLibrary.Config.HeadDotColor
        items.HeadDot.Visible = false
        items.HeadDot.Parent = screenGui
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = items.HeadDot

        -- Chams (Highlight)
        items.Chams = Instance.new("Highlight")
        items.Chams.Adornee = character
        local _cs = getChamsStyle()
        items.Chams.FillColor = _cs.Color
        items.Chams.FillTransparency = _cs.FillTrans
        items.Chams.OutlineColor = _cs.OutlineColor
        items.Chams.OutlineTransparency = _cs.Outline and _cs.OutlineTrans or 1
        items.Chams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        items.Chams.Parent = screenGui

        -- Skeleton connections: {start part name, end part name}
        local skeletonBones = {
            {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
            {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
            {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
            {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
            {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
        }
        items.Skeleton = {}
        for _, pair in ipairs(skeletonBones) do
            local line = Instance.new("Frame")
            line.BorderSizePixel = 0
            line.BackgroundColor3 = ESPLibrary.Config.SkeletonColor
            line.AnchorPoint = Vector2.new(0, 0.5)
            line.Visible = false
            line.Parent = screenGui
            TableInsert(items.Skeleton, {
                line = line,
                aName = pair[1], bName = pair[2],
                aPart = character:FindFirstChild(pair[1]),
                bPart = character:FindFirstChild(pair[2])
            })
        end

        local function update()
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            items.HealthText.Text = round(healthPercent * 100, 1)
            local healthColor = ESPLibrary.Config.LowHealth:Lerp(ESPLibrary.Config.MidHealth, healthPercent)
            healthColor = healthColor:Lerp(ESPLibrary.Config.HighHealth, healthPercent)
            items.HealthText.TextColor3 = healthColor

            local playerFlags = {}
            local plr = Players:GetPlayerFromCharacter(character)
            if plr then
                local clanTag = plr:GetAttribute("ClanTag")
                local clanColor = plr:GetAttribute("ClanColor")
                local isVIP = plr:GetAttribute("VIP")
                local inSafeZone = plr:GetAttribute("SafeZone")
                if clanTag and clanTag ~= "" then
                    local color = clanColor or Color3.fromRGB(255, 255, 255)
                    local r, g, b = math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)
                    TableInsert(playerFlags, string.format('<font color="rgb(%d,%d,%d)">%s</font>', r, g, b, tostring(clanTag)))
                end
                if isVIP then TableInsert(playerFlags, '<font color="rgb(255,215,0)">VIP</font>') end
                if inSafeZone then TableInsert(playerFlags, '<font color="rgb(0,255,120)">Safezone</font>') end
            end
            items.Flags.Text = TableConcat(playerFlags, '\n')

            local distance = (humanoidRootPart.Position - Camera.CFrame.Position).Magnitude
            items.Distance.Text = string.format('%.1fst', distance)
            items.Weapon.Text = getWeapon(character)

            local config = ESPLibrary.Config
            local fontSize = config.FontSize
            local tc = config.TextColor
            items.HealthText.TextSize = fontSize
            items.Name.TextSize = fontSize
            items.Distance.TextSize = fontSize
            items.Weapon.TextSize = fontSize
            items.Flags.TextSize = fontSize
            if Library then
                local f = Library.Font
                items.HealthText.FontFace = f; items.Name.FontFace = f; items.Distance.FontFace = f; items.Weapon.FontFace = f; items.Flags.FontFace = f
            end
            items.Name.TextColor3 = tc; items.Distance.TextColor3 = tc; items.Weapon.TextColor3 = tc; items.Flags.TextColor3 = tc

            local screenSize = Camera.ViewportSize
            local vp, onScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
            local headPos = character:FindFirstChild("Head") and Camera:WorldToViewportPoint(character.Head.Position)
            local rootOnScreen = onScreen
            local visible = rootOnScreen and config.Enabled and distance <= config.MaxDistance
            items.Main.Visible = visible
            items.HeadDot.Visible = config.HeadDot and headPos and headPos.Z > 0
            items.Tracer.Visible = config.Tracers and visible

            if visible then
                local px, py = math.floor(vp.X + 0.5), math.floor(vp.Y + 0.5)
                items.Main.Position = UDim2.fromOffset(px, py)
                local theta = math.tan(math.rad(Camera.FieldOfView) / 2)
                local depth = 2 * vp.Z * theta
                local scale = Camera.ViewportSize.Y / (depth * 1.5)
                local bw, bh = math.floor(math.max(scale * 6, 4)), math.floor(math.max(scale * 8, 4))
                items.Main.Size = UDim2.fromOffset(bw, bh)
                items.Main.BackgroundTransparency = config.BoxFill and config.BoxFillTransparency or 1
                items.Main.BackgroundColor3 = config.BoxFillColor or Color3.fromRGB(0, 0, 0)

                items.BoxOutline.Enabled = config.Box and config.BoxStyle == "Full"
                items.BoxOutline.Color = config.BoxColor
                items.BoxAccent.Enabled = config.Box and config.BoxStyle == "Full"
                items.BoxAccent.Color = config.BoxColor

                -- Corner box
                local cornerStyle = config.Box and config.BoxStyle == "Corners"
                local cl = 8
                for name, data in pairs(items.BoxCorners) do
                    local h = data.h; local v = data.v
                    h.Visible = cornerStyle; h.BackgroundColor3 = config.BoxColor
                    v.Visible = cornerStyle; v.BackgroundColor3 = config.BoxColor
                    if name == "TL" then
                        h.Size = UDim2.fromOffset(cl, 2); h.Position = UDim2.fromOffset(0, 0)
                        v.Size = UDim2.fromOffset(2, cl); v.Position = UDim2.fromOffset(0, 0)
                    elseif name == "TR" then
                        h.Size = UDim2.fromOffset(cl, 2); h.Position = UDim2.fromOffset(bw - cl, 0)
                        v.Size = UDim2.fromOffset(2, cl); v.Position = UDim2.fromOffset(bw - 2, 0)
                    elseif name == "BL" then
                        h.Size = UDim2.fromOffset(cl, 2); h.Position = UDim2.fromOffset(0, bh - 2)
                        v.Size = UDim2.fromOffset(2, cl); v.Position = UDim2.fromOffset(0, bh - cl)
                    elseif name == "BR" then
                        h.Size = UDim2.fromOffset(cl, 2); h.Position = UDim2.fromOffset(bw - cl, bh - 2)
                        v.Size = UDim2.fromOffset(2, cl); v.Position = UDim2.fromOffset(bw - 2, bh - cl)
                    end
                end

                items.Healthbar.Visible = config.Healthbar
                items.HealthText.Visible = config.HealthbarText
                items.Name.Visible = config.Names
                items.Distance.Visible = config.DistanceText
                items.Weapon.Visible = config.WeaponText
                items.Flags.Visible = config.Flags

                if config.HealthbarText then
                    items.HealthText.Position = UDim2.fromOffset(-10, -1)
                end

                local hbOnLeft = config.Healthbar
                items.Left.Visible = hbOnLeft or config.HealthbarText
                local ts = fontSize + 2
                items.Name.Position = UDim2.fromOffset(-2, -ts - 2)

                local bottomY = bh + 2
                if config.DistanceText or config.WeaponText then
                    items.Distance.Position = UDim2.fromOffset(-2, bottomY)
                    items.Weapon.Position = UDim2.fromOffset(-2, bottomY + ts + 1)
                end
                if config.Flags then
                    items.Flags.Position = UDim2.fromOffset(bw + 2, 0)
                end

                -- Text outline & background (cached strokes)
                items.NameStroke.Enabled = config.TextOutline
                items.DistanceStroke.Enabled = config.TextOutline
                items.WeaponStroke.Enabled = config.TextOutline
                items.FlagsStroke.Enabled = config.TextOutline
                local tb = config.TextBackground and 0.3 or 1
                items.Name.BackgroundTransparency = tb; items.Distance.BackgroundTransparency = tb
                items.Weapon.BackgroundTransparency = tb; items.Flags.BackgroundTransparency = tb
            end

            if config.HeadDot and headPos and headPos.Z > 0 then
                items.HeadDot.Position = UDim2.fromOffset(math.floor(headPos.X + 0.5), math.floor(headPos.Y + 0.5))
                items.HeadDot.BackgroundColor3 = config.HeadDotColor
            end

            if config.Tracers and visible then
                local origin = config.TracerOrigin or "Bottom"
                local cx, cy
                if origin == "Camera" then
                    cx, cy = screenSize.X / 2, screenSize.Y / 2
                else
                    cx, cy = screenSize.X / 2, screenSize.Y
                end
                local dx, dy = vp.X - cx, vp.Y - cy
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 0 then
                    items.Tracer.Size = UDim2.fromOffset(math.floor(len + 0.5), config.TracerThickness or 1)
                    items.Tracer.Position = UDim2.fromOffset(math.floor(cx + 0.5), math.floor(cy + 0.5))
                    items.Tracer.Rotation = math.deg(math.atan2(dy, dx))
                    items.Tracer.BackgroundColor3 = config.TracerColor
                end
            end

            -- Chams
            if config.Chams and config.ChamsPlayer and visible then
                local _cs = getChamsStyle()
                local _isRainbow = config.ChamsStyle == "Rainbow"
                items.Chams.FillColor = _isRainbow and rainbowColor(tick()) or _cs.Color
                items.Chams.FillTransparency = _cs.FillTrans
                items.Chams.OutlineColor = _isRainbow and rainbowColor(tick() + 1) or _cs.OutlineColor
                items.Chams.OutlineTransparency = _cs.Outline and _cs.OutlineTrans or 1
                if config.ChamsDepthMode == "Occluded" then
                    items.Chams.DepthMode = Enum.HighlightDepthMode.Occluded
                else
                    items.Chams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
            else
                items.Chams.FillTransparency = 1
                items.Chams.OutlineTransparency = 1
            end

            -- Skeleton (cached parts)
            local skVisible = config.Skeleton and visible
            for _, sk in ipairs(items.Skeleton) do
                local pA = sk.aPart
                if not pA or not pA.Parent then pA = character:FindFirstChild(sk.aName); sk.aPart = pA end
                local pB = sk.bPart
                if not pB or not pB.Parent then pB = character:FindFirstChild(sk.bName); sk.bPart = pB end
                if skVisible and pA and pB then
                    local vpA = Camera:WorldToViewportPoint(pA.Position)
                    local vpB = Camera:WorldToViewportPoint(pB.Position)
                    if vpA.Z > 0 and vpB.Z > 0 then
                        local mx, my = (vpA.X + vpB.X) / 2, (vpA.Y + vpB.Y) / 2
                        local dx, dy = vpB.X - vpA.X, vpB.Y - vpA.Y
                        local len = math.sqrt(dx * dx + dy * dy)
                        sk.line.Size = UDim2.fromOffset(math.max(math.floor(len + 0.5), 1), 1)
                        sk.line.Position = UDim2.fromOffset(math.floor(mx + 0.5), math.floor(my + 0.5))
                        sk.line.Rotation = math.deg(math.atan2(dy, dx))
                        sk.line.BackgroundColor3 = config.SkeletonColor
                        sk.line.Visible = true
                    else
                        sk.line.Visible = false
                    end
                else
                    sk.line.Visible = false
                end
            end
        end

        local data = {
            items = items,
            character = character,
            humanoid = humanoid,
            root = humanoidRootPart,
            update = update,
            created = tick()
        }
        if player then espCache[player] = data end
        return data
    end

    function ESPLibrary:RemoveESP(player)
        local data = espCache[player]
        if data then
            data.items.Main:Destroy()
            data.items.Tracer:Destroy()
            data.items.HeadDot:Destroy()
            if data.items.Chams then data.items.Chams:Destroy() end
            if data.items.Skeleton then
                for _, sk in ipairs(data.items.Skeleton) do sk.line:Destroy() end
            end
            espCache[player] = nil
        end
    end

    function ESPLibrary:UpdateESP(player)
        local data = espCache[player]
        if not data then return end

        local character = data.character
        local items = data.items
        local humanoidRootPart = data.root

        if not character or not character.Parent or not humanoidRootPart or not humanoidRootPart.Parent then
            self:RemoveESP(player); return
        end
        if data.humanoid.Health <= 0 then
            self:RemoveESP(player); return
        end

        local config = ESPLibrary.Config
        local teamCheck = config.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team
        if teamCheck then
            items.Main.Visible = false; items.Tracer.Visible = false; items.HeadDot.Visible = false
            return
        end
        data.update()
    end

    function ESPLibrary:ConnectPlayer(player)
        if player == LocalPlayer then return end

        if player.Character then
            task.spawn(self.CreateESP, self, player, player.Character)
        end

        player.CharacterAdded:Connect(function(character)
            task.spawn(function()
                local hum = character:WaitForChild("Humanoid", 5)
                local hrp = character:WaitForChild("HumanoidRootPart", 5)
                if not hum or not hrp then return end
                repeat task.wait() until hum.Health > 0
                self:CreateESP(player, character)
            end)
        end)
    end

    function ESPLibrary:CreateNPCESP(character)
        local hum = character:FindFirstChild("Humanoid")
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or espCache[character] or npcCache[character] then return end
        local data = self:CreateESP(nil, character)
        if data then npcCache[character] = data end
    end

    function ESPLibrary:UpdateNPC(npcChar)
        local data = npcCache[npcChar]
        if not data then return end
        local character = data.character
        local humanoidRootPart = data.root
        if not character or not character.Parent or not humanoidRootPart or not humanoidRootPart.Parent then
            self:RemoveNPC(npcChar); return
        end
        if data.humanoid.Health <= 0 then
            self:RemoveNPC(npcChar); return
        end
        data.update()
    end

    function ESPLibrary:RemoveNPC(npcChar)
        local data = npcCache[npcChar]
        if data then
            if data.items then
                if data.items.Main then data.items.Main:Destroy() end
                if data.items.Tracer then data.items.Tracer:Destroy() end
                if data.items.HeadDot then data.items.HeadDot:Destroy() end
                if data.items.Chams then data.items.Chams:Destroy() end
                if data.items.Skeleton then
                    for _, sk in ipairs(data.items.Skeleton) do sk.line:Destroy() end
                end
            end
            npcCache[npcChar] = nil
        end
    end

    function ESPLibrary:ScanNPCs()
        local playerChars = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then playerChars[p.Character] = true end
        end
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Model") and not playerChars[v] then
                local hum = v:FindFirstChild("Humanoid")
                local hrp = v:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 and not npcCache[v] and not espCache[v] then
                    self:CreateNPCESP(v)
                end
            end
        end
    end

    function ESPLibrary:Initialize()
        for _, player in ipairs(Players:GetPlayers()) do
            self:ConnectPlayer(player)
        end

        Players.PlayerAdded:Connect(function(player)
            self:ConnectPlayer(player)
        end)

        local espTick = 0
        renderTasks.ESP = function()
            espTick = espTick + 1
            if espTick < 4 then return end
            espTick = 0
            for player, _ in pairs(espCache) do
                self:UpdateESP(player)
            end
            if ESPLibrary.Config.NPCs then
                for npcChar, _ in pairs(npcCache) do
                    self:UpdateNPC(npcChar)
                end
            end
        end

        task.spawn(function()
            while task.wait(1) do
                for player, _ in pairs(espCache) do
                    local char = player.Character
                    if not char then
                        self:RemoveESP(player)
                    end
                end
                for npcChar, _ in pairs(npcCache) do
                    local hum = npcChar:FindFirstChild("Humanoid")
                    local hrp = npcChar:FindFirstChild("HumanoidRootPart")
                    if not hum or not hrp or hum.Health <= 0 or not npcChar.Parent then
                        self:RemoveNPC(npcChar)
                    end
                end
            end
        end)

        task.spawn(function()
            while task.wait(3) do
                if ESPLibrary.Config.NPCs then
                    self:ScanNPCs()
                else
                    for npcChar, _ in pairs(npcCache) do
                        self:RemoveNPC(npcChar)
                    end
                end
            end
        end)
    end

    function ESPLibrary:Destroy()
        for player, _ in pairs(espCache) do
            self:RemoveESP(player)
        end
        for npcChar, _ in pairs(npcCache) do
            self:RemoveNPC(npcChar)
        end
        screenGui:Destroy()
    end

    _G.ESPLibrary = ESPLibrary
    ESPLibrary:Initialize()
end

do
    local vmChamsHighlights = {}
    local function updateVMChams()
        local config = _G.ESPLibrary and _G.ESPLibrary.Config
        if not config or not config.ChamsVM then
            for _, h in pairs(vmChamsHighlights) do h:Destroy() end
            vmChamsHighlights = {}
            return
        end
        local cam = workspace.CurrentCamera
        local vm = cam and cam:FindFirstChildOfClass("Model")
        if not vm or not vm:FindFirstChildWhichIsA("Humanoid") then
            for _, h in pairs(vmChamsHighlights) do h:Destroy() end
            vmChamsHighlights = {}
            return
        end
        local _depthMode = config.ChamsDepthMode == "Occluded" and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
        for _, part in ipairs(vm:GetDescendants()) do
            if part:IsA("BasePart") then
                if not vmChamsHighlights[part] then
                    local h = Instance.new("Highlight")
                    h.Name = "VMChams"
                    h.Adornee = part
                    h.Parent = part
                    vmChamsHighlights[part] = h
                end
                local h = vmChamsHighlights[part]
                local _cs = getChamsStyle()
                local _isRainbow = config.ChamsStyle == "Rainbow"
                h.FillColor = _isRainbow and rainbowColor(tick()) or _cs.Color
                h.FillTransparency = _cs.FillTrans
                h.OutlineColor = _isRainbow and rainbowColor(tick() + 1) or _cs.OutlineColor
                h.OutlineTransparency = _cs.Outline and _cs.OutlineTrans or 1
                h.DepthMode = _depthMode
            end
        end
        for part, h in pairs(vmChamsHighlights) do
            if not part.Parent or not part:IsDescendantOf(vm) then
                h:Destroy(); vmChamsHighlights[part] = nil
            end
        end
    end
    local vmChamsTick = 0
    renderTasks.VMChams = function() vmChamsTick = vmChamsTick + 1; if vmChamsTick < 6 then return end; vmChamsTick = 0; updateVMChams() end
end

do
    local chamsTargetHighlights = {}
    local function applyChamsToPart(part)
        if chamsTargetHighlights[part] then return chamsTargetHighlights[part] end
        local h = Instance.new("Highlight")
        h.Name = "ChamsTarget"
        h.Adornee = part
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = part
        chamsTargetHighlights[part] = h
        return h
    end
    local function updateChamsTargets()
        local config = _G.ESPLibrary and _G.ESPLibrary.Config
        if not config or not config.ChamsTargets then
            for _, h in pairs(chamsTargetHighlights) do h:Destroy() end
            chamsTargetHighlights = {}
            return
        end
        local _cs = getChamsStyle()
        local _isRainbow = config.ChamsStyle == "Rainbow"
        local _fill = _isRainbow and rainbowColor(tick()) or _cs.Color
        local _outline = _isRainbow and rainbowColor(tick() + 1) or _cs.OutlineColor
        local _depthMode = config.ChamsDepthMode == "Occluded" and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
        local _outlineTrans = _cs.Outline and _cs.OutlineTrans or 1
        local _fillTrans = _cs.FillTrans
        local usedParts = {}

        for _, pl in ipairs(Players:GetPlayers()) do
            if pl == LocalPlayer then continue end
            local char = pl.Character
            if not char then continue end

            if config.ChamsHead then
                local head = char:FindFirstChild("Head")
                if head and head:IsA("BasePart") then
                    local h = applyChamsToPart(head)
                    h.FillColor = _fill; h.FillTransparency = _fillTrans
                    h.OutlineColor = _outline; h.OutlineTransparency = _outlineTrans
                    h.DepthMode = _depthMode
                    usedParts[head] = true
                end
            end

            if config.ChamsAccessory then
                for _, acc in ipairs(char:GetChildren()) do
                    if acc:IsA("Accessory") then
                        local handle = acc:FindFirstChild("Handle")
                        if handle and handle:IsA("BasePart") then
                            local h = applyChamsToPart(handle)
                            h.FillColor = _fill; h.FillTransparency = _fillTrans
                            h.OutlineColor = _outline; h.OutlineTransparency = _outlineTrans
                            h.DepthMode = _depthMode
                            usedParts[handle] = true
                        end
                    end
                end
            end

            if config.ChamsMesh or config.ChamsWeapon then
                for _, part in ipairs(char:GetChildren()) do
                    if config.ChamsMesh and (part:IsA("MeshPart") or part:IsA("BasePart")) then
                        local h = applyChamsToPart(part)
                        h.FillColor = _fill; h.FillTransparency = _fillTrans
                        h.OutlineColor = _outline; h.OutlineTransparency = _outlineTrans
                        h.DepthMode = _depthMode
                        usedParts[part] = true
                    end
                    if config.ChamsWeapon and part:IsA("Tool") then
                        for _, wp in ipairs(part:GetChildren()) do
                            if wp:IsA("BasePart") then
                                local h = applyChamsToPart(wp)
                                h.FillColor = _fill; h.FillTransparency = _fillTrans
                                h.OutlineColor = _outline; h.OutlineTransparency = _outlineTrans
                                h.DepthMode = _depthMode
                                usedParts[wp] = true
                            end
                        end
                    end
                end
            end
        end

        for _, h in pairs(chamsTargetHighlights) do
            if not usedParts[h.Adornee] then
                h:Destroy()
            end
        end
        for part, h in pairs(chamsTargetHighlights) do
            if not usedParts[part] then chamsTargetHighlights[part] = nil end
        end
    end
    local chamsTargetTick = 0
    renderTasks.ChamsTargets = function() chamsTargetTick = chamsTargetTick + 1; if chamsTargetTick < 6 then return end; chamsTargetTick = 0; updateChamsTargets() end
end

-- Visuals Page
local VisualsPage = Library.Page(Window, { Name = "Visuals", Columns = 2 })

do
    local s = Library.Pages.Section(VisualsPage, { Name = "General", Side = 1 })
    s:Toggle({ Name = "Enabled", Flag = "VisEnabled", Default = false, Callback = function(state) _G.ESPLibrary.Config.Enabled = state end })
    s:Slider({ Name = "Max Distance", Flag = "VisMaxDistance", Min = 100, Max = 5000, Default = 2000, Suffix = "st", Decimals = 0, Callback = function(value) _G.ESPLibrary.Config.MaxDistance = value end })
    s:Toggle({ Name = "Team Check", Flag = "VisTeamCheck", Default = true, Callback = function(state) _G.ESPLibrary.Config.TeamCheck = state end })
    s:Toggle({ Name = "NPCs", Flag = "VisNPCs", Default = false, Callback = function(state) _G.ESPLibrary.Config.NPCs = state end })
    s:Toggle({ Name = "Box", Flag = "VisBox", Default = false, Callback = function(state) _G.ESPLibrary.Config.Box = state end })
    s:Toggle({ Name = "Box Fill", Flag = "VisBoxFill", Default = false, Callback = function(state) _G.ESPLibrary.Config.BoxFill = state end })
    local boxFillC = s:Label({ Name = "Box Fill Color" })
    boxFillC:Colorpicker({ Name = "Color", Flag = "VisBoxFillColor", Default = Color3.fromRGB(0, 0, 0), Callback = function(c) _G.ESPLibrary.Config.BoxFillColor = c end })
    s:Slider({ Name = "Box Fill Transparency", Flag = "VisBoxFillTrans", Min = 0, Max = 1, Default = 0.5, Suffix = "", Decimals = 2, Callback = function(v) _G.ESPLibrary.Config.BoxFillTransparency = v end })
    local boxC = s:Label({ Name = "Box Color" })
    boxC:Colorpicker({ Name = "Color", Flag = "VisBoxColor", Default = Color3.fromRGB(255, 255, 255), Callback = function(c) _G.ESPLibrary.Config.BoxColor = c end })
    s:Dropdown({ Name = "Box Style", Flag = "VisBoxStyle", Default = "Full", Items = { "Full", "Corners" }, Callback = function(v) _G.ESPLibrary.Config.BoxStyle = v end })
    s:Toggle({ Name = "Tracers", Flag = "VisTracers", Default = false, Callback = function(state) _G.ESPLibrary.Config.Tracers = state end })
    local tracerC = s:Label({ Name = "Tracer Color" })
    tracerC:Colorpicker({ Name = "Color", Flag = "VisTracerColor", Default = Color3.fromRGB(255, 255, 255), Callback = function(c) _G.ESPLibrary.Config.TracerColor = c end })
    s:Slider({ Name = "Tracer Thickness", Flag = "VisTracerThickness", Min = 1, Max = 6, Default = 1, Suffix = "", Decimals = 0, Callback = function(v) _G.ESPLibrary.Config.TracerThickness = v end })
    s:Dropdown({ Name = "Tracer Origin", Flag = "VisTracerOrigin", Default = "Bottom", Items = { "Bottom", "Camera" }, Callback = function(v) _G.ESPLibrary.Config.TracerOrigin = v end })
    s:Toggle({ Name = "Head Dot", Flag = "VisHeadDot", Default = false, Callback = function(state) _G.ESPLibrary.Config.HeadDot = state end })
    local dotC = s:Label({ Name = "Dot Color" })
    dotC:Colorpicker({ Name = "Color", Flag = "VisHeadDotColor", Default = Color3.fromRGB(255, 0, 0), Callback = function(c) _G.ESPLibrary.Config.HeadDotColor = c end })
    s:Toggle({ Name = "Chams", Flag = "VisChams", Default = false, Callback = function(state) _G.ESPLibrary.Config.Chams = state end })
    s:Dropdown({ Name = "Style", Flag = "VisChamsStyle", Items = {"Default","ForceField","Neon","Ghost","XRay","Heatmap","Rainbow"}, Value = "Default", Callback = function(value) _G.ESPLibrary.Config.ChamsStyle = value end })
    s:Dropdown({ Name = "Depth", Flag = "VisChamsDepthMode", Default = "AlwaysOnTop", Items = { "AlwaysOnTop", "Occluded" }, Callback = function(v) _G.ESPLibrary.Config.ChamsDepthMode = v end })
    s:Toggle({ Name = "Chams Targets", Flag = "VisChamsTargetsEnabled", Default = false, Callback = function(state) _G.ESPLibrary.Config.ChamsTargets = state end })
    s:Toggle({ Name = "  Player", Flag = "VisChamsTargetPlayer", Default = true, Callback = function(state) _G.ESPLibrary.Config.ChamsPlayer = state end })
    s:Toggle({ Name = "  VM", Flag = "VisChamsTargetVM", Default = false, Callback = function(state) _G.ESPLibrary.Config.ChamsVM = state end })
    s:Toggle({ Name = "  Mesh", Flag = "VisChamsTargetMesh", Default = false, Callback = function(state) _G.ESPLibrary.Config.ChamsMesh = state end })
    s:Toggle({ Name = "  Weapon", Flag = "VisChamsTargetWeapon", Default = false, Callback = function(state) _G.ESPLibrary.Config.ChamsWeapon = state end })
    s:Toggle({ Name = "  Head", Flag = "VisChamsTargetHead", Default = false, Callback = function(state) _G.ESPLibrary.Config.ChamsHead = state end })
    s:Toggle({ Name = "  Accessory", Flag = "VisChamsTargetAccessory", Default = false, Callback = function(state) _G.ESPLibrary.Config.ChamsAccessory = state end })
    s:Divider()
    s:Toggle({ Name = "Skeleton", Flag = "VisSkeleton", Default = false, Callback = function(state) _G.ESPLibrary.Config.Skeleton = state end })
    local skelC = s:Label({ Name = "Skeleton Color" })
    skelC:Colorpicker({ Name = "Color", Flag = "VisSkeletonColor", Default = Color3.fromRGB(255, 255, 255), Callback = function(c) _G.ESPLibrary.Config.SkeletonColor = c end })
end

do
    local s = Library.Pages.Section(VisualsPage, { Name = "Info", Side = 2 })
    s:Toggle({ Name = "Healthbar", Flag = "VisHealthbar", Default = false, Callback = function(state) _G.ESPLibrary.Config.Healthbar = state end })
    s:Toggle({ Name = "Health Text", Flag = "VisHealthbarText", Default = false, Callback = function(state) _G.ESPLibrary.Config.HealthbarText = state end })
    local highHp = s:Label({ Name = "High Health" })
    highHp:Colorpicker({ Name = "Color", Flag = "VisHighHealth", Default = Color3.fromRGB(0, 255, 0), Callback = function(c) _G.ESPLibrary.Config.HighHealth = c end })
    local midHp = s:Label({ Name = "Mid Health" })
    midHp:Colorpicker({ Name = "Color", Flag = "VisMidHealth", Default = Color3.fromRGB(255, 165, 0), Callback = function(c) _G.ESPLibrary.Config.MidHealth = c end })
    local lowHp = s:Label({ Name = "Low Health" })
    lowHp:Colorpicker({ Name = "Color", Flag = "VisLowHealth", Default = Color3.fromRGB(255, 0, 0), Callback = function(c) _G.ESPLibrary.Config.LowHealth = c end })
    s:Toggle({ Name = "Names", Flag = "VisNames", Default = false, Callback = function(state) _G.ESPLibrary.Config.Names = state end })
    s:Toggle({ Name = "Distance", Flag = "VisDistanceText", Default = false, Callback = function(state) _G.ESPLibrary.Config.DistanceText = state end })
    s:Toggle({ Name = "Weapon", Flag = "VisWeaponText", Default = false, Callback = function(state) _G.ESPLibrary.Config.WeaponText = state end })
    s:Toggle({ Name = "Flags", Flag = "VisFlags", Default = false, Callback = function(state) _G.ESPLibrary.Config.Flags = state end })
    s:Slider({ Name = "Font Size", Flag = "VisFontSize", Min = 8, Max = 32, Default = 12, Suffix = "", Decimals = 0, Callback = function(value) _G.ESPLibrary.Config.FontSize = value end })
    local col = s:Label({ Name = "Text Color" })
    col:Colorpicker({ Name = "Color", Flag = "VisTextColor", Default = Color3.fromRGB(255, 255, 255), Callback = function(color) _G.ESPLibrary.Config.TextColor = color end })
    s:Toggle({ Name = "Text Outline", Flag = "VisTextOutline", Default = false, Callback = function(state) _G.ESPLibrary.Config.TextOutline = state end })
    s:Toggle({ Name = "Text Background", Flag = "VisTextBackground", Default = false, Callback = function(state) _G.ESPLibrary.Config.TextBackground = state end })
end

-- Misc Page
local MiscPage = Library.Page(Window, { Name = "Misc", Columns = 2 })

local function reapplyMisc(char)
    if not char or not Library or not Library.Flags then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return end
    if Library.Flags.WorldFlyEnabled and heartbeatTasks.Fly then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hum.PlatformStand = true end
    end
    if Library.Flags.WorldSpeedEnabled then hum.WalkSpeed = Library.Flags.WorldSpeedValue or 50 end
    if Library.Flags.WorldJumpEnabled then hum.JumpPower = Library.Flags.WorldJumpValue or 75 end
    if Library.Flags.WorldHipEnabled then hum.HipHeight = Library.Flags.WorldHipValue or 2 end
end
LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.5); reapplyMisc(c)
end)

-- Left Column: Movement
do
    local s = Library.Pages.Section(MiscPage, { Name = "Movement", Side = 1 })

    -- Walkspeed
    local _speedToggle = s:Toggle({ Name = "Walkspeed", Flag = "WorldSpeedEnabled", Default = false, Callback = function(state)
        if not Library or not Library.Flags then return end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.WalkSpeed = state and (Library.Flags.WorldSpeedValue or 50) or 16 end
        end
    end })
    _speedToggle:Keybind({ Name = "Keybind", Flag = "WorldSpeedKeybind", Callback = function(state) if Library then Library.SetFlags["WorldSpeedEnabled"](state) end end })
    s:Slider({ Name = "Walkspeed", Flag = "WorldSpeedValue", Min = 16, Max = 350, Default = 50, Suffix = "", Decimals = 0, Callback = function(value) if Library.Flags.WorldSpeedEnabled then local char = LocalPlayer.Character; if char then local hum = char:FindFirstChildWhichIsA("Humanoid"); if hum then hum.WalkSpeed = value end end end end })

    -- Jump Power
    local _jumpToggle = s:Toggle({ Name = "Jump Power", Flag = "WorldJumpEnabled", Default = false, Callback = function(state)
        if not Library or not Library.Flags then return end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.JumpPower = state and (Library.Flags.WorldJumpValue or 75) or 50 end
        end
    end })
    _jumpToggle:Keybind({ Name = "Keybind", Flag = "WorldJumpKeybind", Callback = function(state) if Library then Library.SetFlags["WorldJumpEnabled"](state) end end })
    s:Slider({ Name = "Jump Power", Flag = "WorldJumpValue", Min = 50, Max = 300, Default = 75, Suffix = "", Decimals = 0, Callback = function(value) if Library and Library.Flags and Library.Flags.WorldJumpEnabled then local char = LocalPlayer.Character; if char then local hum = char:FindFirstChildWhichIsA("Humanoid"); if hum then hum.JumpPower = value end end end end })

    -- Hip Height
    local _hipToggle = s:Toggle({ Name = "Hip Height", Flag = "WorldHipEnabled", Default = false, Callback = function(state)
        if not Library or not Library.Flags then return end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.HipHeight = state and (Library.Flags.WorldHipValue or 2) or 0 end
        end
    end })
    _hipToggle:Keybind({ Name = "Keybind", Flag = "WorldHipKeybind", Callback = function(state) if Library then Library.SetFlags["WorldHipEnabled"](state) end end })
    s:Slider({ Name = "Hip Height", Flag = "WorldHipValue", Min = 0, Max = 20, Default = 2, Suffix = "", Decimals = 1, Callback = function(value) if Library and Library.Flags and Library.Flags.WorldHipEnabled then local char = LocalPlayer.Character; if char then local hum = char:FindFirstChildWhichIsA("Humanoid"); if hum then hum.HipHeight = value end end end end })

    -- Fly
    local _flyToggle = s:Toggle({ Name = "Fly", Flag = "WorldFlyEnabled", Default = false, Callback = function(state)
        if not Library or not Library.Flags then return end
        if state then
            local speed = Library.Flags.WorldFlySpeed or 50
            heartbeatTasks.Fly = function()
                local char = LocalPlayer.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                if not hrp or not hum then return end
                local cam = workspace.CurrentCamera
                    local moveDir = Vector3New(0, 0, 0)
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3New(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir + Vector3New(0, -1, 0) end
                    local bv = hrp:FindFirstChildOfClass("BodyVelocity")
                    if not bv then
                        bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3New(1e5, 1e5, 1e5)
                        bv.Parent = hrp
                    end
                    bv.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * speed or Vector3New(0, 0, 0)
                    hum.PlatformStand = true
                end
        else
            heartbeatTasks.Fly = function() end
            task.spawn(function()
                local char = LocalPlayer.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local bv = hrp:FindFirstChildOfClass("BodyVelocity")
                    if bv then bv:Destroy() end
                end
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                if hum then hum.PlatformStand = false end
            end)
        end
    end })
    _flyToggle:Keybind({ Name = "Keybind", Flag = "WorldFlyKeybind", Callback = function(state) if Library then Library.SetFlags["WorldFlyEnabled"](state) end end })
    s:Slider({ Name = "Fly Speed", Flag = "WorldFlySpeed", Min = 1, Max = 300, Default = 50, Suffix = "", Decimals = 0 })

    -- Inf Jump
    local infJumpConnection
    local _infJumpToggle = s:Toggle({ Name = "Inf Jump", Flag = "WorldInfJump", Default = false, Callback = function(state)
        if state then
            if not infJumpConnection then
                infJumpConnection = UserInputService.JumpRequest:Connect(function()
                    local char = LocalPlayer.Character
                    if not char then return end
                    local hum = char:FindFirstChildWhichIsA("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                end)
            end
        elseif infJumpConnection then
            infJumpConnection:Disconnect(); infJumpConnection = nil
        end
    end })
    _infJumpToggle:Keybind({ Name = "Keybind", Flag = "WorldInfJumpKeybind", Callback = function(state) if Library then Library.SetFlags["WorldInfJump"](state) end end })

    -- Click TP
    local clickTPConnection
    local _clickTPToggle = s:Toggle({ Name = "Click TP", Flag = "WorldClickTP", Default = false, Callback = function(state)
        if state then
            if not clickTPConnection then
                clickTPConnection = UserInputService.InputBegan:Connect(function(input, processed)
                    if processed then return end
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mouse = LocalPlayer:GetMouse()
                        local target = mouse.Hit
                        if target then
                            local char = LocalPlayer.Character
                            if char then
                                local hrp = char:FindFirstChild("HumanoidRootPart")
                                if hrp then hrp.CFrame = CFrame.new(target.Position + Vector3New(0, 3, 0)) end
                            end
                        end
                    end
                end)
            end
        elseif clickTPConnection then
            clickTPConnection:Disconnect(); clickTPConnection = nil
        end
    end })
    _clickTPToggle:Keybind({ Name = "Keybind", Flag = "WorldClickTPKeybind", Callback = function(state) if Library then Library.SetFlags["WorldClickTP"](state) end end })

    -- Override Gravity
    local _gravityToggle = s:Toggle({ Name = "Override Gravity", Flag = "WorldGravityEnabled", Default = false, Callback = function(state) if not Library or not Library.Flags then return end; if state then pcall(function() game:GetService("Workspace").Gravity = Library.Flags.WorldGravity or 196.2 end) else pcall(function() game:GetService("Workspace").Gravity = 196.2 end) end end })
    _gravityToggle:Keybind({ Name = "Keybind", Flag = "WorldGravityKeybind", Callback = function(state) if Library then Library.SetFlags["WorldGravityEnabled"](state) end end })
    s:Slider({ Name = "Gravity", Flag = "WorldGravity", Min = -500, Max = 500, Default = 196.2, Suffix = "", Decimals = 1, Callback = function(value) if Library and Library.Flags and Library.Flags.WorldGravityEnabled then pcall(function() game:GetService("Workspace").Gravity = value end) end end })
    s:Button({ Name = "Reset Gravity", Callback = function() if not Library then return end; pcall(function() game:GetService("Workspace").Gravity = 196.2 end); if Library.Flags then Library.Flags.WorldGravity = 196.2; Library.Flags.WorldGravityEnabled = false end; if Library.Theme then Library:Notification("Gravity reset to 196.2", 2, Library.Theme.Accent) end end })
end

-- Left Column: Player
do
    local s = Library.Pages.Section(MiscPage, { Name = "Player", Side = 1 })

    -- No Clip
    local _noclipToggle = s:Toggle({ Name = "No Clip", Flag = "WorldNoclipEnabled", Default = false, Callback = function(state)
        if state then
            steppedTasks.NoClip = function()
                local char = LocalPlayer.Character
                if not char then return end
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        else
            steppedTasks.NoClip = function() end
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
    end })
    _noclipToggle:Keybind({ Name = "Keybind", Flag = "WorldNoclipKeybind", Callback = function(state) if Library then Library.SetFlags["WorldNoclipEnabled"](state) end end })

    -- Third Person
    local _tpToggle = s:Toggle({ Name = "Third Person", Flag = "WorldThirdPerson", Default = false, Callback = function(state) end })
    _tpToggle:Keybind({ Name = "Keybind", Flag = "WorldThirdPersonKeybind", Callback = function(st) if Library then Library.SetFlags["WorldThirdPerson"](st) end end })
    s:Slider({ Name = "Distance", Flag = "WorldThirdPersonDist", Min = 3, Max = 30, Default = 10, Suffix = "", Decimals = 0 })
    heartbeatTasks.ThirdPerson = function()
        local tp = Library and Library.Flags and Library.Flags.WorldThirdPerson
        if not tp then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if not hrp then return end
        local dist = Library.Flags.WorldThirdPersonDist or 10
        local offset = -cam.CFrame.LookVector * dist + Vector3New(0, 3, 0)
        cam.CFrame = CFrame.new(hrp.Position + offset, hrp.Position)
    end
end

-- Right Column: World
do
    local s = Library.Pages.Section(MiscPage, { Name = "World", Side = 2 })

    -- FOV Changer
    s:Toggle({ Name = "FOV Changer", Flag = "WorldFOVEnabled", Default = false, Callback = function(state)
        if not Library or not Library.Flags then return end
        if state then
            renderTasks.FOV = function()
                local cam = workspace.CurrentCamera
                if cam then cam.FieldOfView = Library.Flags.WorldFOVValue or 90 end
            end
        else
            renderTasks.FOV = function() end
            local cam = workspace.CurrentCamera
            if cam then cam.FieldOfView = 70 end
        end
    end })
    s:Slider({ Name = "Field of View", Flag = "WorldFOVValue", Min = 10, Max = 180, Default = 90, Suffix = "°", Decimals = 0, Callback = function(value) if Library and Library.Flags and Library.Flags.WorldFOVEnabled then local cam = workspace.CurrentCamera; if cam then cam.FieldOfView = value end end end })
end

-- Right Column: Hypershot Spoofer
do
    local s = Library.Pages.Section(MiscPage, { Name = "Hypershot Spoofer", Side = 2 })

    -- Username Spoofer
    s:Toggle({ Name = "Spoof Username", Flag = "HypSpoofUsername", Default = false, Callback = function(state)
        if not Library or not Library.Flags then return end
        if state then
            local name = Library.Flags.HypSpoofedName or "Player"
            steppedTasks.SpoofUsername = function()
                pcall(function()
                    LocalPlayer.DisplayName = name
                    LocalPlayer.Name = name
                end)
            end
        else
            steppedTasks.SpoofUsername = function() end
            pcall(function()
                LocalPlayer.DisplayName = LocalPlayer.Name
            end)
        end
    end })
    s:Textbox({ Name = "Spoofed Name", Flag = "HypSpoofedName", Placeholder = "Enter name...", Default = "Player" })

    -- Avatar Spoofer (by username)
    local spoofAvatarCharConn
    local cachedAvatarDesc
    s:Toggle({ Name = "Spoof Avatar", Flag = "HypSpoofAvatar", Default = false, Callback = function(state)
        if not Library or not Library.Flags then return end
        if state then
            local username = Library.Flags.HypSpoofedUser or "Player"
            local success, userId = pcall(Players.GetUserIdFromNameAsync, Players, username)
            local apply
            if success and userId then
                local descSuccess, desc = pcall(function()
                    local d = Instance.new("HumanoidDescription")
                    d:FillFromUserUserId(userId)
                    return d
                end)
                if descSuccess and desc then
                    cachedAvatarDesc = desc
                    apply = function()
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildWhichIsA("Humanoid")
                            if hum then pcall(function() hum:ApplyDescription(cachedAvatarDesc) end) end
                        end
                    end
                    apply()
                    spoofAvatarCharConn = LocalPlayer.CharacterAdded:Connect(function()
                        task.wait(1)
                        apply()
                    end)
                end
            end
            if apply then steppedTasks.SpoofAvatar = apply end
        else
            steppedTasks.SpoofAvatar = function() end
            if spoofAvatarCharConn then spoofAvatarCharConn:Disconnect(); spoofAvatarCharConn = nil end
            cachedAvatarDesc = nil
        end
    end })
    s:Textbox({ Name = "Target Username", Flag = "HypSpoofedUser", Placeholder = "Enter Roblox username...", Default = "Player" })

    -- Level Spoofer (Hypershot-compatible)
    local statNames = {"Level","level","Rank","rank","Wins","Kills","Deaths","Score","Points","XP","Experience","Matches","KDRatio","Coins","Money","Cash","Reputation","Prestige","Tier","Division","Badge","Progress","Stars","Tokens","Gems","EXP","Lvl","LVL","Wave","Round","Streak","Rating","MMR","Skill","Season","BattlePass","Pass","Credits","Essence","Shards"}
    s:Toggle({ Name = "Spoof Level", Flag = "HypSpoofLevel", Default = false, Callback = function(state)
        if not Library or not Library.Flags then return end
        if state then
            local level = Library.Flags.HypSpoofedLevel or 100
            steppedTasks.SpoofLevel = function()
                pcall(function()
                    for _, obj in ipairs(LocalPlayer:GetDescendants()) do
                        if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                            for _, name in ipairs(statNames) do
                                if obj.Name == name then
                                    obj.Value = level
                                    break
                                end
                            end
                        end
                    end
                end)
            end
        else
            steppedTasks.SpoofLevel = function() end
        end
    end })
    s:Slider({ Name = "Spoofed Level", Flag = "HypSpoofedLevel", Min = 1, Max = 99999, Default = 9999, Suffix = "", Decimals = 0 })
end

-- World Page
local WorldPage = Library.Page(Window, { Name = "World", Columns = 2 })
local Lightning = game:GetService("Lighting")
local WorldSection = Library.Pages.Section(WorldPage, { Name = "Environment", Side = 1 })
WorldSection:Toggle({ Name = "Override Ambient", Flag = "WorldAmbientEnabled", Default = false, Callback = function(state) if state then pcall(function() Lightning.Ambient = Library.Flags.WorldAmbient or Color3.fromRGB(127, 127, 127) end) else pcall(function() Lightning.Ambient = Color3.fromRGB(127, 127, 127) end) end end })
local ambientLabel = WorldSection:Label({ Name = "Ambient" })
ambientLabel:Colorpicker({ Name = "Color", Flag = "WorldAmbient", Default = Color3.fromRGB(127, 127, 127), Callback = function(color) if Library.Flags.WorldAmbientEnabled then pcall(function() Lightning.Ambient = color end) end end })
WorldSection:Toggle({ Name = "Override Fog", Flag = "WorldFogEnabled", Default = false, Callback = function(state) if state then pcall(function() Lightning.FogColor = Library.Flags.WorldFogColor or Color3.fromRGB(127, 127, 127); Lightning.FogEnd = Library.Flags.WorldFogEnd or 100000; Lightning.FogStart = Library.Flags.WorldFogStart or 0 end) else pcall(function() Lightning.FogColor = Color3.fromRGB(127, 127, 127); Lightning.FogEnd = 100000; Lightning.FogStart = 0 end) end end })
local fogLabel = WorldSection:Label({ Name = "Fog" })
fogLabel:Colorpicker({ Name = "Color", Flag = "WorldFogColor", Default = Color3.fromRGB(127, 127, 127), Callback = function(color) if Library.Flags.WorldFogEnabled then pcall(function() Lightning.FogColor = color end) end end })
WorldSection:Slider({ Name = "Fog End", Flag = "WorldFogEnd", Min = 1, Max = 100000, Default = 100000, Suffix = "", Decimals = 1, Callback = function(value) if Library.Flags.WorldFogEnabled then pcall(function() Lightning.FogEnd = value end) end end })
WorldSection:Slider({ Name = "Fog Start", Flag = "WorldFogStart", Min = 0, Max = 100000, Default = 0, Suffix = "", Decimals = 1, Callback = function(value) if Library.Flags.WorldFogEnabled then pcall(function() Lightning.FogStart = value end) end end })
WorldSection:Slider({ Name = "Brightness", Flag = "WorldBrightness", Min = 0, Max = 10, Default = 2, Suffix = "", Decimals = 1, Callback = function(value) pcall(function() Lightning.Brightness = value end) end })
WorldSection:Slider({ Name = "Clock Time", Flag = "WorldClockTime", Min = 0, Max = 24, Default = 12, Suffix = "", Decimals = 1, Callback = function(value) pcall(function() Lightning.ClockTime = value end) end })
WorldSection:Divider()
WorldSection:Toggle({ Name = "Override Outdoor Ambient", Flag = "WorldOutdoorAmbientEnabled", Default = false, Callback = function(state) if state then pcall(function() Lightning.OutdoorAmbient = Library.Flags.WorldOutdoorAmbient or Color3.fromRGB(127, 127, 127) end) else pcall(function() Lightning.OutdoorAmbient = Color3.fromRGB(127, 127, 127) end) end end })
local outdoorLabel = WorldSection:Label({ Name = "Outdoor Ambient" })
outdoorLabel:Colorpicker({ Name = "Color", Flag = "WorldOutdoorAmbient", Default = Color3.fromRGB(127, 127, 127), Callback = function(color) if Library.Flags.WorldOutdoorAmbientEnabled then pcall(function() Lightning.OutdoorAmbient = color end) end end })
WorldSection:Toggle({ Name = "Override Exposure", Flag = "WorldExposureEnabled", Default = false, Callback = function(state) if state then pcall(function() Lightning.ExposureCompensation = Library.Flags.WorldExposure or 1 end) else pcall(function() Lightning.ExposureCompensation = 1 end) end end })
WorldSection:Slider({ Name = "Exposure", Flag = "WorldExposure", Min = -3, Max = 3, Default = 1, Suffix = "", Decimals = 2, Callback = function(value) if Library.Flags.WorldExposureEnabled then pcall(function() Lightning.ExposureCompensation = value end) end end })
WorldSection:Toggle({ Name = "Global Shadows", Flag = "WorldGlobalShadows", Default = true, Callback = function(state) pcall(function() Lightning.GlobalShadows = state end) end })
WorldSection:Button({ Name = "Reset All Environment", Callback = function()
    pcall(function() Lightning.Ambient = Color3.fromRGB(127, 127, 127); Lightning.OutdoorAmbient = Color3.fromRGB(127, 127, 127); Lightning.Brightness = 2; Lightning.ClockTime = 12; Lightning.FogColor = Color3.fromRGB(127, 127, 127); Lightning.FogEnd = 100000; Lightning.FogStart = 0; Lightning.ExposureCompensation = 1; Lightning.GlobalShadows = true end)
    Library:Notification("Environment reset to defaults", 2, Library.Theme.Accent)
end })

-- Atmosphere Section (Side 1)
atmosphereInstance = nil
local function getAtmos()
    if not atmosphereInstance then
        atmosphereInstance = Instance.new("Atmosphere")
        pcall(function()
            atmosphereInstance.Density = Library.Flags.WorldAtmosDensity or 0.5
            atmosphereInstance.Offset = Library.Flags.WorldAtmosOffset or 0.5
            atmosphereInstance.Glare = Library.Flags.WorldAtmosGlare or 0.5
            atmosphereInstance.Haze = Library.Flags.WorldAtmosHaze or 0.5
        end)
        atmosphereInstance.Parent = Lightning
    end
    return atmosphereInstance
end
local AtmosphereSection = Library.Pages.Section(WorldPage, { Name = "Atmosphere", Side = 1 })
AtmosphereSection:Toggle({ Name = "Enable Atmosphere", Flag = "WorldAtmosphereEnabled", Default = false, Callback = function(state)
    if state then pcall(getAtmos)
    elseif atmosphereInstance then pcall(function() atmosphereInstance:Destroy() end); atmosphereInstance = nil end
end })
AtmosphereSection:Slider({ Name = "Density", Flag = "WorldAtmosDensity", Min = 0, Max = 1, Default = 0.5, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldAtmosphereEnabled then pcall(function() getAtmos().Density = value end) end end })
AtmosphereSection:Slider({ Name = "Offset", Flag = "WorldAtmosOffset", Min = 0, Max = 1, Default = 0.5, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldAtmosphereEnabled then pcall(function() getAtmos().Offset = value end) end end })
local atmosColorLabel = AtmosphereSection:Label({ Name = "Color" })
atmosColorLabel:Colorpicker({ Name = "Color", Flag = "WorldAtmosColor", Default = Color3.fromRGB(127, 150, 200), Callback = function(color) if Library.Flags.WorldAtmosphereEnabled then pcall(function() getAtmos().Color = color end) end end })
local atmosDecayLabel = AtmosphereSection:Label({ Name = "Decay" })
atmosDecayLabel:Colorpicker({ Name = "Decay", Flag = "WorldAtmosDecay", Default = Color3.fromRGB(200, 180, 150), Callback = function(color) if Library.Flags.WorldAtmosphereEnabled then pcall(function() getAtmos().Decay = color end) end end })
AtmosphereSection:Slider({ Name = "Glare", Flag = "WorldAtmosGlare", Min = 0, Max = 1, Default = 0.5, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldAtmosphereEnabled then pcall(function() getAtmos().Glare = value end) end end })
AtmosphereSection:Slider({ Name = "Haze", Flag = "WorldAtmosHaze", Min = 0, Max = 1, Default = 0.5, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldAtmosphereEnabled then pcall(function() getAtmos().Haze = value end) end end })

-- Skybox Section (Side 2)
local SkyboxSection = Library.Pages.Section(WorldPage, { Name = "Skybox", Side = 2 })
local skyboxPresets = {
    Galaxy = {"15125283003","15125281008","15125277539","15125279325","15125274388","15125275800"},
    ["Purple Nebula"] = {"159454299","159454296","159454293","159454286","159454300","159454288"},
    Vaporwave = {"1417494030","1417494146","1417494253","1417494402","1417494499","1417494643"},
    Sunset = {"626460377","626460216","626460513","626473032","626458639","626460625"},
    ["Dark Night"] = {"6285719338","6285721078","6285722964","6285724682","6285726335","6285730635"},
    Twilight = {"264908339","264907909","264909420","264909758","264908886","264907379"},
    Cloudy = {"4495864450","4495864887","4495865458","4495866035","4495866584","4495867486"},
    Stormy = {"4498828382","4498828812","4498829917","4498830911","4498830417","4498831746"},
    Chill = {"5084575798","5084575916","5103949679","5103948542","5103948784","5084576400"},
    ["Lake Sky"] = {"6823531746","6823528533","6823525702","6823482923","6823530023","6823523318"},
}
local skyboxKeys = {}
for k in pairs(skyboxPresets) do table.insert(skyboxKeys, k) end
table.sort(skyboxKeys)

local function clearExistingSky()
    local existing = Lightning:FindFirstChildOfClass("Sky")
    if existing then existing:Destroy() end
end

local function setSkyFaces(sky, ids)
    if not sky or not ids then return end
    sky.SkyboxBk = "rbxassetid://" .. ids[1]
    sky.SkyboxDn = "rbxassetid://" .. ids[2]
    sky.SkyboxFt = "rbxassetid://" .. ids[3]
    sky.SkyboxLf = "rbxassetid://" .. ids[4]
    sky.SkyboxRt = "rbxassetid://" .. ids[5]
    sky.SkyboxUp = "rbxassetid://" .. ids[6]
end

local function applySkybox(ids)
    clearExistingSky()
    if skyboxInstance then pcall(function() skyboxInstance:Destroy() end); skyboxInstance = nil end
    if not ids then return end
    skyboxInstance = Instance.new("Sky")
    setSkyFaces(skyboxInstance, ids)
    skyboxInstance.Parent = Lightning
end

SkyboxSection:Toggle({ Name = "Custom Skybox", Flag = "WorldSkyboxEnabled", Default = false, Callback = function(state)
    if state then
        local name = Library.Flags.WorldSkyboxPreset
        local ids = name and skyboxPresets[name] or skyboxPresets[skyboxKeys[1]]
        if ids then applySkybox(ids) end
    else
        if skyboxInstance then pcall(function() skyboxInstance:Destroy() end); skyboxInstance = nil end
    end
end })
SkyboxSection:Dropdown({ Name = "Preset", Flag = "WorldSkyboxPreset", Items = skyboxKeys, Default = "Galaxy", Callback = function(value)
    if not value then return end
    if Library.Flags.WorldSkyboxEnabled then
        local ids = skyboxPresets[value]
        if ids then applySkybox(ids) end
        Library:Notification("Skybox: " .. value, 2, Library.Theme.Accent)
    end
end })
SkyboxSection:Button({ Name = "Clear Skybox", Callback = function()
    if skyboxInstance then pcall(function() skyboxInstance:Destroy() end); skyboxInstance = nil end
    Library:Notification("Skybox cleared", 2, Library.Theme.Accent)
end })
SkyboxSection:Toggle({ Name = "Auto-Rotate Skybox", Flag = "WorldSkyboxRotate", Default = false })
heartbeatTasks.SkyboxRotate = function(dt)
    if Library and Library.Flags.WorldSkyboxRotate and skyboxInstance then
        skyboxInstance.SkyboxOrientation = Vector3New(0, (skyboxInstance.SkyboxOrientation.Y + dt * 2) % 360, 0)
    end
end

-- Time Cycle Section (Side 2)
local TimeSection = Library.Pages.Section(WorldPage, { Name = "Time Cycle", Side = 2 })
local timeDisplay = TimeSection:Label({ Name = "Current Time: 12:00" })
TimeSection:Toggle({ Name = "Auto Time Cycle", Flag = "WorldTimeCycleEnabled", Default = false, Callback = function(state)
    if state then
        local speed = Library.Flags.WorldTimeCycleSpeed or 1
        heartbeatTasks.TimeCycle = function(dt)
            pcall(function() Lightning.ClockTime = (Lightning.ClockTime + dt * speed * 0.01) % 24 end)
        end
    else
        heartbeatTasks.TimeCycle = function() end
    end
end })
TimeSection:Slider({ Name = "Cycle Speed", Flag = "WorldTimeCycleSpeed", Min = 0, Max = 10, Default = 1, Suffix = "", Decimals = 1 })
-- Update time display every second
task.spawn(function()
    while task.wait(1) do
        local t = math.floor(Lightning.ClockTime or 12)
        local h, m = t, (t - math.floor(t)) * 60
        if not Library or not Library.Flags then break end
        pcall(function() timeDisplay:UpdateText(string.format("Current Time: %02d:%02d", h % 24, math.floor(m))) end)
    end
end)

-- Water Section (Side 2)
local WaterSection = Library.Pages.Section(WorldPage, { Name = "Water", Side = 2 })
local Terrain = game:GetService("Workspace").Terrain
WaterSection:Toggle({ Name = "Override Water", Flag = "WorldWaterEnabled", Default = false, Callback = function(state) if not state then pcall(function() Terrain.WaterColor = Color3.fromRGB(50, 100, 200); Terrain.WaterTransparency = 0; Terrain.WaterReflectance = 0 end) end end })
local waterColorLabel = WaterSection:Label({ Name = "Water Color" })
waterColorLabel:Colorpicker({ Name = "Color", Flag = "WorldWaterColor", Default = Color3.fromRGB(50, 100, 200), Callback = function(color) if Library.Flags.WorldWaterEnabled then pcall(function() Terrain.WaterColor = color end) end end })
WaterSection:Slider({ Name = "Transparency", Flag = "WorldWaterTransparency", Min = 0, Max = 1, Default = 0, Suffix = "", Decimals = 2, Callback = function(value) if Library.Flags.WorldWaterEnabled then pcall(function() Terrain.WaterTransparency = value end) end end })
WaterSection:Slider({ Name = "Reflectance", Flag = "WorldWaterReflectance", Min = 0, Max = 1, Default = 0, Suffix = "", Decimals = 2, Callback = function(value) if Library.Flags.WorldWaterEnabled then pcall(function() Terrain.WaterReflectance = value end) end end })
WaterSection:Button({ Name = "Reset Water", Callback = function()
    pcall(function() Terrain.WaterColor = Color3.fromRGB(50, 100, 200); Terrain.WaterTransparency = 0; Terrain.WaterReflectance = 0 end)
    Library:Notification("Water reset to defaults", 2, Library.Theme.Accent)
end })

-- Post-Processing Section (Side 2)
bloomInstance = nil
colorCorrectionInstance = nil
sunRaysInstance = nil
local function safeGetColor(flag, default)
    local v = Library.Flags[flag]
    if typeof(v) == "Color3" then return v end
    if type(v) == "table" and v.Color then return v.Color end
    return default
end
local PostSection = Library.Pages.Section(WorldPage, { Name = "Post-Processing", Side = 2 })
PostSection:Toggle({ Name = "Bloom", Flag = "WorldBloomEnabled", Default = false, Callback = function(state)
    if state then
        if not bloomInstance then
            pcall(function()
                bloomInstance = Instance.new("BloomEffect")
                bloomInstance.Intensity = Library.Flags.WorldBloomIntensity or 0.5
                bloomInstance.Size = Library.Flags.WorldBloomSize or 24
                bloomInstance.Threshold = Library.Flags.WorldBloomThreshold or 2
                bloomInstance.Parent = Lightning
            end)
        end
    elseif bloomInstance then pcall(function() bloomInstance:Destroy() end); bloomInstance = nil end
end })
PostSection:Slider({ Name = "Intensity", Flag = "WorldBloomIntensity", Min = 0, Max = 1, Default = 0.5, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldBloomEnabled and bloomInstance then pcall(function() bloomInstance.Intensity = value end) end end })
PostSection:Slider({ Name = "Size", Flag = "WorldBloomSize", Min = 0, Max = 56, Default = 24, Suffix = "", Decimals = 0, Callback = function(value) if Library.Flags.WorldBloomEnabled and bloomInstance then pcall(function() bloomInstance.Size = value end) end end })
PostSection:Slider({ Name = "Threshold", Flag = "WorldBloomThreshold", Min = 0, Max = 4, Default = 2, Suffix = "", Decimals = 1, Callback = function(value) if Library.Flags.WorldBloomEnabled and bloomInstance then pcall(function() bloomInstance.Threshold = value end) end end })
PostSection:Divider()
PostSection:Toggle({ Name = "Color Correction", Flag = "WorldColorCorrectionEnabled", Default = false, Callback = function(state)
    if state then
        if not colorCorrectionInstance then
            pcall(function()
                colorCorrectionInstance = Instance.new("ColorCorrectionEffect")
                colorCorrectionInstance.Brightness = Library.Flags.WorldCCBrightness or 0
                colorCorrectionInstance.Contrast = Library.Flags.WorldCCContrast or 0
                colorCorrectionInstance.Saturation = Library.Flags.WorldCCSaturation or 0
                colorCorrectionInstance.TintColor = safeGetColor("WorldCCTint", Color3.fromRGB(255, 255, 255))
                colorCorrectionInstance.Parent = Lightning
            end)
        end
    elseif colorCorrectionInstance then pcall(function() colorCorrectionInstance:Destroy() end); colorCorrectionInstance = nil end
end })
PostSection:Slider({ Name = "Brightness", Flag = "WorldCCBrightness", Min = -1, Max = 1, Default = 0, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldColorCorrectionEnabled and colorCorrectionInstance then pcall(function() colorCorrectionInstance.Brightness = value end) end end })
PostSection:Slider({ Name = "Contrast", Flag = "WorldCCContrast", Min = -1, Max = 1, Default = 0, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldColorCorrectionEnabled and colorCorrectionInstance then pcall(function() colorCorrectionInstance.Contrast = value end) end end })
PostSection:Slider({ Name = "Saturation", Flag = "WorldCCSaturation", Min = -1, Max = 1, Default = 0, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldColorCorrectionEnabled and colorCorrectionInstance then pcall(function() colorCorrectionInstance.Saturation = value end) end end })
local tintLabel = PostSection:Label({ Name = "Tint" })
tintLabel:Colorpicker({ Name = "Tint", Flag = "WorldCCTint", Default = Color3.fromRGB(255, 255, 255), Callback = function(color) if Library.Flags.WorldColorCorrectionEnabled and colorCorrectionInstance then pcall(function() colorCorrectionInstance.TintColor = color end) end end })
PostSection:Divider()
PostSection:Toggle({ Name = "Sun Rays", Flag = "WorldSunRaysEnabled", Default = false, Callback = function(state)
    if state then
        if not sunRaysInstance then
            pcall(function()
                sunRaysInstance = Instance.new("SunRaysEffect")
                sunRaysInstance.Intensity = Library.Flags.WorldSunRaysIntensity or 0.05
                sunRaysInstance.Spread = Library.Flags.WorldSunRaysSpread or 1
                sunRaysInstance.Parent = Lightning
            end)
        end
    elseif sunRaysInstance then pcall(function() sunRaysInstance:Destroy() end); sunRaysInstance = nil end
end })
PostSection:Slider({ Name = "Rays Intensity", Flag = "WorldSunRaysIntensity", Min = 0, Max = 1, Default = 0.05, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldSunRaysEnabled and sunRaysInstance then pcall(function() sunRaysInstance.Intensity = value end) end end })
PostSection:Slider({ Name = "Rays Spread", Flag = "WorldSunRaysSpread", Min = 0, Max = 1, Default = 1, Suffix = "", Decimals = 3, Callback = function(value) if Library.Flags.WorldSunRaysEnabled and sunRaysInstance then pcall(function() sunRaysInstance.Spread = value end) end end })

-- Settings Page
local MainPage = Library.Page(Window, { Name = "Settings", Columns = 2 })

-- Apply Rose Gold theme on startup
Library:ApplyThemePreset("Rose Gold")


-- General Section (Left Side - UI)
local DisplaySection = Library.Pages.Section(MainPage, { Name = "Display", Side = 1 })
DisplaySection:Toggle({ Name = "Show Watermark", Flag = "ShowWatermark", Default = true, Callback = function(state) Watermark:SetVisibility(state) end })
DisplaySection:Toggle({ Name = "Show Keybind List", Flag = "ShowKeybindList", Default = true, Callback = function(state) KeybindList:SetVisibility(state) end })
DisplaySection:Dropdown({ Name = "Font", Flag = "FontSelection", Items = Library.FontList, Default = "Windows-XP-Tahoma", Callback = function(value)
    if value then Library:SetFont(value) end
end })

local menuKeybindLabel = DisplaySection:Label({ Name = "Menu Keybind: Z (right-click to change)" })
local _menuKeybind = menuKeybindLabel:Keybind({
    Name = "Menu Keybind",
    Flag = "MenuKeybind",
    Default = "Z",
    Mode = "Toggle",
    Callback = function()
        local kb = Library.Flags.MenuKeybind
        if kb and kb.Key then
            local keyName = tostring(kb.Key):gsub("Enum.KeyCode.", "")
            Library.MenuKeybind = kb.Key
            menuKeybindLabel.Elements.Text.Instance.Text = "Menu Keybind: " .. keyName .. " (right-click to change)"
            Library:Notification("Menu keybind changed to: " .. keyName, 3, Color3.fromRGB(0, 255, 0))
        end
    end
})

DisplaySection:Divider()
DisplaySection:Slider({ Name = "Blur Intensity", Flag = "BlurIntensity", Min = 0, Max = 56, Default = 0, Suffix = "", Decimals = 1, Callback = function(value) BlurSetting = value; applyBlur(value) end })

local NotifSection = Library.Pages.Section(MainPage, { Name = "Notifications", Side = 1 })
NotifSection:Button({ Name = "Test Notification", Callback = function() Library:Notification("Test notification!", 3, Library.Theme.Accent) end })
NotifSection:Slider({ Name = "Position X", Flag = "NotifPositionX", Min = 0, Max = 500, Default = 5, Suffix = "", Decimals = 1, Callback = function(value) if Library.NotifHolder then Library.NotifHolder.Instance.Position = UDim2New(0, value, 0, Library.Flags.NotifPositionY or 40) end end })
NotifSection:Slider({ Name = "Position Y", Flag = "NotifPositionY", Min = 0, Max = 500, Default = 40, Suffix = "", Decimals = 1, Callback = function(value) if Library.NotifHolder then Library.NotifHolder.Instance.Position = UDim2New(0, Library.Flags.NotifPositionX or 5, 0, value) end end })

local ParticleSection = Library.Pages.Section(MainPage, { Name = "Particles", Side = 1 })
ParticleSection:Toggle({ Name = "Enabled", Flag = "ParticleEnabled", Default = false, Callback = function(state)
    ParticleSettings.Enabled = state
    if state then startParticleSystem() else stopParticleSystem() end
end })
ParticleSection:Dropdown({ Name = "Mode", Flag = "ParticleMode", Items = {"Snow", "Rain"}, Default = "Rain", Callback = function(value)
    ParticleSettings.Mode = value
    if ParticleSettings.Enabled then
        stopParticleSystem()
        startParticleSystem()
    end
end })
ParticleSection:Slider({ Name = "Count", Flag = "ParticleCount", Min = 10, Max = 200, Default = 50, Suffix = "", Decimals = 1, Callback = function(value)
    ParticleSettings.Count = value
end })
ParticleSection:Slider({ Name = "Snow Speed", Flag = "SnowSpeed", Min = 10, Max = 150, Default = 50, Suffix = "", Decimals = 1, Callback = function(value)
    ParticleSettings.SnowSpeed = value
    if ParticleSettings.Enabled and ParticleSettings.Mode == "Snow" then
        stopParticleSystem()
        startParticleSystem()
    end
end })

local DangerSection = Library.Pages.Section(MainPage, { Name = "Danger Zone", Side = 1 })
DangerSection:Button({ Name = "Unload UI", Callback = function() Library:Unload() end })


-- Config System Section (Right Side)
local ConfigSection = Library.Pages.Section(MainPage, { Name = "Config System", Side = 2 })
local configName = ConfigSection:Textbox({ Name = "Config Name", Flag = "ConfigName", Placeholder = "Enter config name...", Default = "" })
ConfigSection:Divider()
ConfigSection:Label({ Name = "Saved Configs:", Alignment = "Left" })
local configList = ConfigSection:Listbox({ Name = "Configs", Flag = "ConfigList", Items = {}, Size = 100, Callback = function(value)
    if value then configName:Set(value:gsub("%.json$", "")) end
end })

local function refreshConfigList()
    local configs = {}
    if isfolder(Library.Folders.Configs) then
        for _, file in ipairs(listfiles(Library.Folders.Configs)) do
            local fileName = file:match("([^\\/]+)%.json$")
            if fileName then table.insert(configs, fileName .. ".json") end
        end
    end
    configList:Refresh(configs)
end

ConfigSection:Button({ Name = "Refresh Configs", Callback = refreshConfigList })
ConfigSection:Divider()
ConfigSection:Button({ Name = "Save Config", Callback = function()
    local name = configName:Get()
    if name and name ~= "" then
        if not isfolder(Library.Folders.Configs) then makefolder(Library.Folders.Configs) end
        writefile(Library.Folders.Configs .. "/" .. name .. ".json", Library:GetConfig())
        Library:Notification("Config saved: " .. name .. ".json", 3, Color3.fromRGB(0, 255, 0))
        refreshConfigList()
    else
        Library:Notification("Please enter a config name!", 3, Color3.fromRGB(255, 0, 0))
    end
end })
ConfigSection:Button({ Name = "Load Config", Callback = function()
    local name = configName:Get()
    if name and name ~= "" then
        local configPath = Library.Folders.Configs .. "/" .. name .. ".json"
        if isfile(configPath) then
            Library:LoadConfig(readfile(configPath))
        else
            Library:Notification("Config not found: " .. name .. ".json", 3, Color3.fromRGB(255, 0, 0))
        end
    else
        Library:Notification("Please enter a config name!", 3, Color3.fromRGB(255, 0, 0))
    end
end })
ConfigSection:Button({ Name = "Delete Config", Callback = function()
    local name = configName:Get()
    if name and name ~= "" then
        local configPath = Library.Folders.Configs .. "/" .. name .. ".json"
        if isfile(configPath) then
            delfile(configPath)
            Library:Notification("Deleted config: " .. name .. ".json", 3, Color3.fromRGB(255, 0, 0))
            refreshConfigList()
        else
            Library:Notification("Config not found: " .. name .. ".json", 3, Color3.fromRGB(255, 0, 0))
        end
    else
        Library:Notification("Please enter a config name!", 3, Color3.fromRGB(255, 0, 0))
    end
end })



-- Themes Page
local ThemesPage = Library.Page(Window, { Name = "Themes", Columns = 2 })

-- Theme Presets Section (Left Side)
local PresetSection = Library.Pages.Section(ThemesPage, { Name = "Theme Presets", Side = 1 })

local themePresetKeys = {}
for k in pairs(ThemePresets) do table.insert(themePresetKeys, k) end
table.sort(themePresetKeys)

PresetSection:Label({ Name = "Select a preset to instantly change all colors" })
PresetSection:Dropdown({
    Name = "Select Theme",
    Flag = "ThemePreset",
    Items = themePresetKeys,
    Default = "Rose Gold",
    Callback = function(value)
        if value then
            Library:ApplyThemePreset(value)
            Library:Notification("Applied theme: " .. value, 3, Library.Theme.Accent)
        end
    end
})

PresetSection:Divider()
PresetSection:Label({ Name = "Fine-tune each color below or save a custom theme" })
PresetSection:Button({ Name = "Reset to Rose Gold", Callback = function() Library:ApplyThemePreset("Rose Gold"); Library:Notification("Theme reset to Rose Gold!", 3, Library.Theme.Accent) end })

-- Custom Colors Section (Right Side)
local ColorSection = Library.Pages.Section(ThemesPage, { Name = "Custom Colors", Side = 2 })

local themeNameBox = ColorSection:Textbox({ Name = "Theme Name", Flag = "ThemeConfigName", Placeholder = "My Theme...", Default = "" })
ColorSection:Divider()

ColorSection:Label({ Name = "Saved Themes:", Alignment = "Left" })
local themeListbox = ColorSection:Listbox({ Name = "Saved Themes", Flag = "ThemeConfigList", Items = {}, Size = 80, Callback = function(value)
    if value then themeNameBox:Set(value:gsub("%.json$", "")) end
end })

local function saveThemeConfig(name)
    if type(name) ~= "string" or name == "" then return end
    if not isfolder(Library.Folders.Configs .. "/Themes") then makefolder(Library.Folders.Configs .. "/Themes") end
    local data = {}
    for key, color in pairs(Library.Theme) do
        data[key] = {color.R, color.G, color.B}
    end
    writefile(Library.Folders.Configs .. "/Themes/" .. name .. ".json", game:GetService("HttpService"):JSONEncode(data))
end

local function loadThemeConfig(name)
    if type(name) ~= "string" or name == "" then return end
    local path = Library.Folders.Configs .. "/Themes/" .. name .. ".json"
    if isfile(path) then
        local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(path)) end)
        if ok and type(data) == "table" then
            for key, rgb in pairs(data) do
                if Library.Theme[key] and type(rgb) == "table" and #rgb == 3 then
                    Library:ChangeTheme(key, Color3.new(rgb[1], rgb[2], rgb[3]))
                end
            end
            Library:Notification("Loaded theme: " .. name, 3, Library.Theme.Accent)
        end
    end
end

local function refreshThemeList()
    local items = {}
    if isfolder(Library.Folders.Configs .. "/Themes") then
        for _, file in ipairs(listfiles(Library.Folders.Configs .. "/Themes")) do
            local fn = file:match("([^\\/]+)%.json$")
            if fn then table.insert(items, fn) end
        end
    end
    themeListbox:Refresh(items)
end

ColorSection:Button({ Name = "Save Current Theme", Callback = function()
    local n = themeNameBox:Get()
    if type(n) == "string" and n ~= "" then
        saveThemeConfig(n)
        refreshThemeList()
        Library:Notification("Theme saved: " .. n, 3, Library.Theme.Accent)
    else
        Library:Notification("Enter a theme name!", 3, Color3.fromRGB(255, 0, 0))
    end
end })
ColorSection:Button({ Name = "Load Selected", Callback = function()
    local n = themeListbox:Get()
    if type(n) == "string" then
        loadThemeConfig(n)
        refreshThemeList()
    else
        Library:Notification("Select a theme to load!", 3, Color3.fromRGB(255, 0, 0))
    end
end })
ColorSection:Button({ Name = "Delete Selected", Callback = function()
    local n = themeListbox:Get()
    if type(n) == "string" then
        local path = Library.Folders.Configs .. "/Themes/" .. n .. ".json"
        if isfile(path) then delfile(path); refreshThemeList(); Library:Notification("Deleted: " .. n, 3, Library.Theme.Accent) end
    else
        Library:Notification("Select a theme to delete!", 3, Color3.fromRGB(255, 0, 0))
    end
end })

local bgLabel = ColorSection:Label({ Name = "Background" })
bgLabel:Colorpicker({ Name = "Main BG", Flag = "ThemeBackground", Default = Color3.fromRGB(22, 12, 16), Callback = function(color) Library:ChangeTheme("Background", color) end })

local inlineLabel = ColorSection:Label({ Name = "Inline" })
inlineLabel:Colorpicker({ Name = "Inline BG", Flag = "ThemeInline", Default = Color3.fromRGB(30, 18, 22), Callback = function(color) Library:ChangeTheme("Inline", color) end })

local accentLabel = ColorSection:Label({ Name = "Accent" })
accentLabel:Colorpicker({ Name = "Accent Color", Flag = "ThemeAccent", Default = Color3.fromRGB(255, 182, 193), Callback = function(color) Library:ChangeTheme("Accent", color) end })

local textLabel = ColorSection:Label({ Name = "Text" })
textLabel:Colorpicker({ Name = "Text Color", Flag = "ThemeText", Default = Color3.fromRGB(240, 220, 225), Callback = function(color) Library:ChangeTheme("Text", color) end })

local elementLabel = ColorSection:Label({ Name = "Element" })
elementLabel:Colorpicker({ Name = "Element BG", Flag = "ThemeElement", Default = Color3.fromRGB(48, 30, 36), Callback = function(color) Library:ChangeTheme("Element", color) end })

refreshConfigList()





-- Stabilize character to prevent sinking after load
task.delay(0.5, function()
    local char = LocalPlayer.Character
    if not char then
        local conn
        conn = LocalPlayer.CharacterAdded:Connect(function(c)
            conn:Disconnect()
            char = c
            local hum = char:WaitForChild("Humanoid", 3)
            if hum and hum:IsA("Humanoid") then
                hum.HipHeight = hum.HipHeight
            end
        end)
        return
    end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then
        hum.AutoRotate = true
        hum.PlatformStand = false
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, bv in pairs(hrp:GetChildren()) do
            if bv:IsA("BodyVelocity") or bv:IsA("BodyPosition") or bv:IsA("BodyGyro") then
                bv:Destroy()
            end
        end
    end
end)
