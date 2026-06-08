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
            local ResizeButton=Instances:Create("TextButton",{Parent=Gui,AnchorPoint=Vector2New(1,1),BorderColor3=FromRGB(0,0,0),Size=UDim2New(0,12,0,12),Position=UDim2New(1,0,1,0),Name="\0",BorderSizePixel=2,BackgroundColor3=FromRGB(40,40,40)})
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
    Library.NotifHolder = Instances:Create("Frame",{Parent=Library.Holder.Instance,BorderColor3=FromRGB(0,0,0),AnchorPoint=Vector2New(0,0),BackgroundTransparency=1,Position=UDim2New(0,5,0,40),Name="\0",Size=UDim2New(0,300,0,300),BorderSizePixel=0})
    Instances:Create("UIListLayout",{Parent=Library.NotifHolder.Instance,VerticalAlignment=Enum.VerticalAlignment.Top,SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Left,Padding=UDimNew(0,5)})

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
        Items["Watermark"]=Instances:Create("Frame",{Parent=Library.Holder.Instance,Size=UDim2New(0,380,0,20),Name="\0",Position=UDim2New(0,15,0,15),BorderColor3=FromRGB(10,10,10),BorderSizePixel=2,BackgroundColor3=FromRGB(15,15,20)})
        Items["Watermark"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Library.NotifHolder.Instance.Parent = Items["Watermark"].Instance
        Library.NotifHolder.Instance.Position = UDim2New(0, 0, 0, 18)
        Library.NotifHolder.Instance.Size = UDim2New(1, -10, 0, 300)
        Instances:Create("UIStroke",{Parent=Items["Watermark"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIPadding",{Parent=Items["Watermark"].Instance,PaddingTop=UDimNew(0,2),PaddingRight=UDimNew(0,8),PaddingLeft=UDimNew(0,8)})
        
        -- Main text label that contains everything
        Items["Title"]=Instances:Create("TextLabel",{Parent=Items["Watermark"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text="",Name="\0",Size=UDim2New(1,0,0,15),BackgroundTransparency=1,BorderSizePixel=0,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left})
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
        Items["Notification"]=Instances:Create("Frame",{Parent=Library.NotifHolder.Instance,Name="\0",Size=UDim2New(0,0,0,22),BorderColor3=FromRGB(10,10,10),BorderSizePixel=2,AutomaticSize=Enum.AutomaticSize.X})
        Items["Notification"]:AddToTheme({BackgroundColor3="Background",BorderColor3="Border"})
        Instances:Create("UIStroke",{Parent=Items["Notification"].Instance,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0",Color=FromRGB(27,27,32)}):AddToTheme({Color="Outline"})
        Instances:Create("UIPadding",{Parent=Items["Notification"].Instance,PaddingTop=UDimNew(0,1),PaddingRight=UDimNew(0,8),PaddingLeft=UDimNew(0,5)})
        Items["Title"]=Instances:Create("TextLabel",{Parent=Items["Notification"].Instance,FontFace=Library.Font,TextColor3=FromRGB(215,215,215),BorderColor3=FromRGB(0,0,0),Text=Text,Name="\0",Size=UDim2New(0,0,0,20),BackgroundTransparency=1,BorderSizePixel=0,TextSize=12})
        Items["Title"]:AddToTheme({TextColor3="Text"})
        Instances:Create("UIStroke",{Parent=Items["Title"].Instance,LineJoinMode=Enum.LineJoinMode.Miter,Name="\0"}):AddToTheme({Color="Text Border"})
        Items["AccentLine"]=Instances:Create("Frame",{Parent=Items["Notification"].Instance,Name="\0",Position=UDim2New(0,-5,0,-1),BorderColor3=FromRGB(0,0,0),Size=UDim2New(1,13,0,2),BorderSizePixel=0,BackgroundColor3=FromRGB(255,255,255)})
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

-- [CONTINUES IN NEXT PART...]
-- The script is too large for one update. The rest will be added in a continuation commit.
-- All the original code has been preserved and is being uploaded in sections.
